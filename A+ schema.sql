-- A+ Schema
CREATE DATABASE IF NOT EXISTS university_lms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE university_lms;

CREATE TABLE departments (dept_id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(150) NOT NULL UNIQUE) ENGINE=InnoDB;
CREATE TABLE roles (role_id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50) NOT NULL UNIQUE) ENGINE=InnoDB;
INSERT INTO roles (name) VALUES ('super_admin'),('department_admin'),('doctor'),('student');

CREATE TABLE users (
  user_id INT AUTO_INCREMENT PRIMARY KEY, role_id INT NOT NULL,
  first_name VARCHAR(50) NOT NULL, middle_name VARCHAR(50) NULL, last_name VARCHAR(50) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE, password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (role_id) REFERENCES roles(role_id)) ENGINE=InnoDB;

CREATE TABLE students (
  user_id INT PRIMARY KEY, student_code VARCHAR(30) NOT NULL UNIQUE, dept_id INT NOT NULL, academic_year SMALLINT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id), FOREIGN KEY (dept_id) REFERENCES departments(dept_id)) ENGINE=InnoDB;
CREATE TABLE doctors (
  user_id INT PRIMARY KEY, dept_id INT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id), FOREIGN KEY (dept_id) REFERENCES departments(dept_id)) ENGINE=InnoDB;
CREATE TABLE department_admins (
  user_id INT PRIMARY KEY, dept_id INT NOT NULL UNIQUE,
  FOREIGN KEY (user_id) REFERENCES users(user_id), FOREIGN KEY (dept_id) REFERENCES departments(dept_id)) ENGINE=InnoDB;

CREATE TABLE semesters (
  semester_id INT AUTO_INCREMENT PRIMARY KEY, start_date DATE NOT NULL, end_date DATE NOT NULL, CHECK (end_date > start_date)) ENGINE=InnoDB;
CREATE TABLE courses (
  course_code VARCHAR(20) PRIMARY KEY, title VARCHAR(200) NOT NULL, dept_id INT NOT NULL, description TEXT NULL,
  FOREIGN KEY (dept_id) REFERENCES departments(dept_id)) ENGINE=InnoDB;
CREATE TABLE course_offerings (
  offering_id INT AUTO_INCREMENT PRIMARY KEY, course_code VARCHAR(20) NOT NULL, semester_id INT NOT NULL,
  UNIQUE (course_code, semester_id),
  FOREIGN KEY (course_code) REFERENCES courses(course_code), FOREIGN KEY (semester_id) REFERENCES semesters(semester_id)) ENGINE=InnoDB;
CREATE TABLE offering_doctors (
  offering_id INT NOT NULL, doctor_id INT NOT NULL, PRIMARY KEY (offering_id, doctor_id),
  FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id), FOREIGN KEY (doctor_id) REFERENCES doctors(user_id)) ENGINE=InnoDB;
CREATE TABLE enrollments (
  offering_id INT NOT NULL, student_id INT NOT NULL, enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (offering_id, student_id),
  FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id), FOREIGN KEY (student_id) REFERENCES students(user_id)) ENGINE=InnoDB;

CREATE TABLE materials (
  material_id INT AUTO_INCREMENT PRIMARY KEY, offering_id INT NOT NULL, title VARCHAR(200) NOT NULL, file_url TEXT NOT NULL,
  uploaded_by INT NOT NULL, uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id), FOREIGN KEY (uploaded_by) REFERENCES doctors(user_id)) ENGINE=InnoDB;

CREATE TABLE assessments (
  assessment_id INT AUTO_INCREMENT PRIMARY KEY, offering_id INT NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('quiz','assignment')),
  title VARCHAR(200) NOT NULL, file_url TEXT NULL,
  requires_file BOOLEAN NOT NULL DEFAULT TRUE,          -- does the student upload a file?
  time_limit_minutes SMALLINT NULL,
  max_score DECIMAL(6,2) NOT NULL, deadline DATETIME NULL,
  created_by INT NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id), FOREIGN KEY (created_by) REFERENCES doctors(user_id)) ENGINE=InnoDB;

CREATE TABLE assessment_questions (
  question_id INT AUTO_INCREMENT PRIMARY KEY, assessment_id INT NOT NULL, question_text TEXT NOT NULL,
  points DECIMAL(5,2) NOT NULL DEFAULT 1, position SMALLINT NOT NULL, UNIQUE (assessment_id, position),
  FOREIGN KEY (assessment_id) REFERENCES assessments(assessment_id) ON DELETE CASCADE) ENGINE=InnoDB;
CREATE TABLE question_options (
  option_id INT AUTO_INCREMENT PRIMARY KEY, question_id INT NOT NULL, option_text TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL DEFAULT FALSE, position SMALLINT NOT NULL,
  UNIQUE (question_id, position), UNIQUE (question_id, option_id),
  FOREIGN KEY (question_id) REFERENCES assessment_questions(question_id) ON DELETE CASCADE) ENGINE=InnoDB;

CREATE TABLE submissions (
  submission_id INT AUTO_INCREMENT PRIMARY KEY, assessment_id INT NOT NULL, student_id INT NOT NULL,
  file_url TEXT NULL, submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (assessment_id, student_id),
  FOREIGN KEY (assessment_id) REFERENCES assessments(assessment_id), FOREIGN KEY (student_id) REFERENCES students(user_id)) ENGINE=InnoDB;
CREATE TABLE submission_answers (
  submission_id INT NOT NULL, question_id INT NOT NULL, selected_option_id INT NULL,
  points_awarded DECIMAL(5,2) NOT NULL DEFAULT 0, PRIMARY KEY (submission_id, question_id),
  FOREIGN KEY (submission_id) REFERENCES submissions(submission_id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES assessment_questions(question_id),
  FOREIGN KEY (question_id, selected_option_id) REFERENCES question_options(question_id, option_id)) ENGINE=InnoDB;

CREATE TABLE ai_feedback (
  feedback_id INT AUTO_INCREMENT PRIMARY KEY, submission_id INT NOT NULL UNIQUE, feedback_text TEXT NOT NULL,
  suggested_score DECIMAL(3,1) NOT NULL CHECK (suggested_score BETWEEN 0 AND 10),
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (submission_id) REFERENCES submissions(submission_id)) ENGINE=InnoDB;
CREATE TABLE assessment_grades (
  grade_id INT AUTO_INCREMENT PRIMARY KEY, submission_id INT NOT NULL UNIQUE, score DECIMAL(6,2) NOT NULL,
  graded_by INT NULL, is_auto BOOLEAN NOT NULL DEFAULT FALSE, graded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (submission_id) REFERENCES submissions(submission_id), FOREIGN KEY (graded_by) REFERENCES doctors(user_id)) ENGINE=InnoDB;

CREATE TABLE attendance_records (
  attendance_id INT AUTO_INCREMENT PRIMARY KEY, offering_id INT NOT NULL, student_id INT NOT NULL, session_date DATE NOT NULL,
  status VARCHAR(10) NOT NULL CHECK (status IN ('present','absent')), recorded_by INT NOT NULL,
  recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE (offering_id, student_id, session_date),
  FOREIGN KEY (offering_id, student_id) REFERENCES enrollments(offering_id, student_id),
  FOREIGN KEY (recorded_by) REFERENCES doctors(user_id)) ENGINE=InnoDB;

CREATE TABLE notifications (
  notification_id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, notification_type VARCHAR(50) NOT NULL,
  message TEXT NOT NULL, is_read BOOLEAN NOT NULL DEFAULT FALSE, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(user_id)) ENGINE=InnoDB;
CREATE TABLE notification_logs (
  log_id INT AUTO_INCREMENT PRIMARY KEY, notification_id INT NOT NULL, user_id INT NOT NULL,
  related_entity_type VARCHAR(50) NULL, related_entity_id INT NULL, channel VARCHAR(30) NOT NULL,
  sent_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (notification_id) REFERENCES notifications(notification_id), FOREIGN KEY (user_id) REFERENCES users(user_id)) ENGINE=InnoDB;

CREATE TABLE student_gamification (
  student_id INT PRIMARY KEY, points INT NOT NULL DEFAULT 0, current_streak INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0, last_activity DATE NULL, FOREIGN KEY (student_id) REFERENCES students(user_id)) ENGINE=InnoDB;
CREATE TABLE badges (
  badge_id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL UNIQUE, description TEXT NULL, criteria TEXT NULL) ENGINE=InnoDB;
CREATE TABLE student_badges (
  student_id INT NOT NULL, badge_id INT NOT NULL, earned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (student_id, badge_id),
  FOREIGN KEY (student_id) REFERENCES students(user_id), FOREIGN KEY (badge_id) REFERENCES badges(badge_id)) ENGINE=InnoDB;
INSERT INTO badges (name, description, criteria) VALUES
 ('First Submission','Submitted your first assessment','submissions>=1'),
 ('Perfect Score','Got full marks on an assessment','score=max'),
 ('7 Day Streak','Active 7 days in a row','streak>=7');

CREATE TABLE course_market (
  course_code VARCHAR(20) PRIMARY KEY, why_important TEXT NULL, suggested_courses TEXT NULL, future_projects TEXT NULL,
  published_by INT NULL, published_at DATETIME NULL,
  FOREIGN KEY (course_code) REFERENCES courses(course_code), FOREIGN KEY (published_by) REFERENCES doctors(user_id)) ENGINE=InnoDB;

CREATE INDEX idx_enrollments_student ON enrollments(student_id);
CREATE INDEX idx_submissions_student ON submissions(student_id);
CREATE INDEX idx_attendance_student ON attendance_records(student_id, offering_id);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
