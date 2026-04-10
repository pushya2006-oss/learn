const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const multer = require("multer");
const cloudinary = require("cloudinary").v2;
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const path = require("path");

const app = express();

app.use(cors({
  origin: "*",
  methods: ["GET", "POST", "DELETE", "PUT", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
}));

app.use(express.json());

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "SECRET_KEY";
const ADMIN_JWT_SECRET = process.env.ADMIN_JWT_SECRET || "ADMIN_SECRET_KEY";

// ================= ADMIN CREDENTIALS =================
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@btech.com";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "admin123";

// ================= CLOUDINARY CONFIG =================
// PDFs are stored on Cloudinary (free 25GB) instead of local disk
// so they work on any server / mobile
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// ================= MULTER → CLOUDINARY =================
const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: "btech_app",
    resource_type: "raw",   // needed for PDFs
    format: "pdf",
    allowed_formats: ["pdf"],
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === ".pdf") cb(null, true);
    else cb(new Error("Only PDF files are allowed"), false);
  },
});

// ================= MONGODB ATLAS =================
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log("✅ MongoDB Atlas Connected"))
  .catch((err) => console.log("❌ MongoDB Error:", err));

// ================= MODELS =================
const User = mongoose.model("User", {
  email: String,
  password: String,
});

const Resource = mongoose.model("Resource", {
  title: String,
  subject: String,
  type: String,
  link: String,
  year: String,
  semester: String,
  exam_year: String,
});

const Exam = mongoose.model("Exam", {
  title: String,
  year: String,
  semester: String,
  subject: String,
  duration: Number,
  scheduledTime: String,
  totalQuestions: Number,
  questions: [{
    question: String,
    options: [String],
    correctOption: String
  }]
});

// ================= USER AUTH ROUTES =================

app.post("/register", async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).send("All fields required");

  const exists = await User.findOne({ email });
  if (exists) return res.status(400).send("User already exists");

  const hashed = await bcrypt.hash(password, 10);
  await new User({ email, password: hashed }).save();
  res.send("User registered successfully");
});

app.post("/login", async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).send("All fields required");

  const user = await User.findOne({ email });
  if (!user) return res.status(400).send("User not found");

  const isMatch = await bcrypt.compare(password, user.password);
  if (!isMatch) return res.status(400).send("Invalid password");

  const token = jwt.sign({ id: user._id, role: "user" }, JWT_SECRET);
  res.json({ token, role: "user" });
});

// ================= ADMIN AUTH ROUTE =================

app.post("/admin/login", async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).send("All fields required");

  if (email !== ADMIN_EMAIL || password !== ADMIN_PASSWORD) {
    return res.status(401).send("Invalid admin credentials");
  }

  const token = jwt.sign({ role: "admin" }, ADMIN_JWT_SECRET, { expiresIn: "1d" });
  res.json({ token, role: "admin" });
});

// ================= AUTH MIDDLEWARES =================

function userAuth(req, res, next) {
  const token = req.headers["authorization"];
  if (!token) return res.status(401).send("Access denied");
  try {
    jwt.verify(token, JWT_SECRET);
    next();
  } catch (err) {
    res.status(400).send("Invalid token");
  }
}

function adminAuth(req, res, next) {
  const token = req.headers["authorization"];
  if (!token) return res.status(401).send("Admin access required");
  try {
    const decoded = jwt.verify(token, ADMIN_JWT_SECRET);
    if (decoded.role !== "admin") {
      return res.status(403).send("Not authorized as admin");
    }
    next();
  } catch (err) {
    res.status(401).send("Invalid or expired admin token");
  }
}

// ================= EXAM ROUTES =================

app.post("/scheduleExam", adminAuth, async (req, res) => {
  try {
    const examData = req.body;
    if (!examData.title || !examData.questions) {
      return res.status(400).send("Title and questions are required");
    }

    const newExam = new Exam(examData);
    await newExam.save();
    res.send("Exam scheduled successfully");
  } catch (err) {
    res.status(500).send("Failed to schedule exam: " + err.message);
  }
});

app.get("/getExams", async (req, res) => {
  try {
    const { subject, year, semester } = req.query;
    const query = {};
    if (subject) query.subject = subject;
    if (year) query.year = year;
    if (semester) query.semester = semester;

    const exams = await Exam.find(query).sort({ scheduledTime: 1 });
    res.json(exams);
  } catch (err) {
    res.status(500).send("Failed to fetch exams");
  }
});

// ================= RESOURCE ROUTES =================

app.get("/getResources", async (req, res) => {
  try {
    res.json(await Resource.find());
  } catch (err) {
    res.status(500).send("Failed to fetch resources");
  }
});

app.get("/getResources/filter", async (req, res) => {
  try {
    const { subject, type, year, semester } = req.query;
    const query = {};
    if (subject) query.subject = subject;
    if (type) query.type = type;
    if (year) query.year = year;
    if (semester) query.semester = semester;
    res.json(await Resource.find(query));
  } catch (err) {
    res.status(500).send("Failed to fetch resources");
  }
});

// ✅ Upload PDF → stored on Cloudinary
app.post("/upload", adminAuth, upload.single("file"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).send("No file uploaded");

    const { title, subject, type, year, semester, exam_year } = req.body;
    if (!title || !subject || !type || !year || !semester)
      return res.status(400).send("All fields are required");

    // Cloudinary returns the public URL in req.file.path
    const fileUrl = req.file.path;

    await new Resource({
      title, subject, type, link: fileUrl,
      year, semester, exam_year: exam_year || "",
    }).save();

    res.send("File uploaded successfully");
  } catch (err) {
    res.status(500).send("Upload failed: " + err.message);
  }
});

app.post("/addLink", adminAuth, async (req, res) => {
  try {
    const { title, subject, link, year, semester } = req.body;
    if (!title || !subject || !link || !year || !semester)
      return res.status(400).send("All fields are required");

    if (!link.startsWith("http://") && !link.startsWith("https://"))
      return res.status(400).send("Link must start with http:// or https://");

    await new Resource({
      title, subject, type: "external",
      link, year, semester, exam_year: "",
    }).save();

    res.send("Link saved successfully");
  } catch (err) {
    res.status(500).send("Failed to save link: " + err.message);
  }
});

app.delete("/deleteResource/:id", adminAuth, async (req, res) => {
  try {
    await Resource.findByIdAndDelete(req.params.id);
    res.send("Resource deleted");
  } catch (err) {
    res.status(500).send("Delete failed");
  }
});

// ================= START =================
app.listen(PORT, () => {
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`🔐 Admin email → ${ADMIN_EMAIL}`);
});