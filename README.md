# IDireksyon

**IDireksyon** is a mobile application designed to help residents of Santa Maria, Bulacan navigate the process of acquiring government-issued IDs.

The application organizes government ID requirements and provides personalized guidance based on the user's goals, existing IDs, and available documents. Through its smart sequencing feature, IDireksyon recommends an appropriate order for completing requirements and obtaining IDs.

## 🎯 Project Goal

IDireksyon aims to make government ID processing easier to understand by turning scattered requirements and procedures into a clear, step-by-step journey.

The application focuses on answering:

> **"What should I do first, what comes next, and where do I go?"**

## ✨ Key Features

- 🛣️ **Personalized ID Roadmap**  
  Provides users with an ordered sequence of recommended steps based on their needs and available documents.

- 🪪 **Government ID Directory**  
  Allows users to browse and learn about different government-issued IDs and their requirements.

- 📄 **Document Inventory**  
  Helps users keep track of the IDs and documents they already have.

- 📍 **Office Finder**  
  Helps users locate relevant government offices and access directions.

- 💰 **Cost Estimation**  
  Provides estimated costs associated with obtaining selected government IDs.

- 📋 **Requirement Guidance**  
  Presents the documents and requirements needed for specific IDs.

## 🧠 Smart Sequencing

IDireksyon uses a **rule-based sequencing approach** rather than artificial intelligence or machine learning.

The recommended sequence considers factors such as:

- User's selected goal
- Existing IDs and documents
- ID requirements
- Prerequisite relationships between requirements
- Document readiness
- Predefined application rules

The resulting sequence is presented to the user as a **personalized ID roadmap**.

## 🛠️ Technology Stack

### Frontend
- Flutter
- Dart

### Backend
- Laravel
- PHP
- REST API

### Database
- MySQL

## 📱 Project Structure

The frontend follows a feature-based Flutter architecture:

```text
lib/
├── core/
├── data/
├── features/
├── admin/
├── services/
└── main.dart
```

## 👥 Development

IDireksyon is an undergraduate capstone project developed by a student team.

The project is currently under active development. Features, interfaces, and system components may change as development and evaluation progress.

📌 Project Status

In Development

Current development focus:

Resident mobile application
User interface implementation
Personalized roadmap
Government ID information
Backend API integration
Smart sequencing logic
