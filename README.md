<div align="left">
  <b><a href="README.ko.md">한국어 Korean</a></b>
</div>

# Snapit: AI-Powered Diet Tracking App

**Just Snap It. We'll Log It.** Snapit is an innovative diet management app where you simply take a photo of your food, and our AI analyzes it to provide accurate nutritional information in just a few seconds.

This project was submitted to the **2025 AWS Lambda Hackathon**.

---

## 🚀 Live Demo

[Snapit Demo Video](https://youtu.be/ksLz942HZTM)

## ✨ Key Features

* **Snap, Tap, Log:** A seamless 3-second process to complete your food logging.
* **Accurate AI Analysis:** Utilizes Amazon Bedrock's multimodal AI to understand the full context of a meal and provide highly reliable nutritional information.
* **Personalized Goal Setting:** The app automatically calculates and sets your recommended daily intake based on the profile and goals you set during onboarding.
* **Asynchronous & Scalable:** Built on an asynchronous architecture using SQS to provide a non-blocking and resilient user experience.

## 🏛️ System Architecture

The entire Snapit application is built on a 100% serverless architecture on AWS.

<img width="2400" alt="Snapit Backend" src="https://github.com/user-attachments/assets/dfdaebaa-6628-4ce9-aae3-046d9180fa5f" />

## How We Used AWS Lambda

AWS Lambda is the core of our entire backend architecture. Instead of managing servers, we adopted a serverless, microservices approach where each Lambda function is a small, independent service responsible for a single, specific task. This design makes our system highly scalable, resilient, and cost-effective.

Below is a detailed breakdown of each Lambda function and its role in the Snapit application, matching our code structure and API Gateway endpoints.

---

### 1. User Profile & Onboarding

These functions handle the creation and retrieval of user-specific data, which is essential for personalizing the app experience.

#### `UpdateOnboardingProfile.py`
* **Trigger:** API Gateway (`PATCH /profile`)
* **Responsibility:** This function is called once when a new user completes their onboarding. It takes the user's personal data (birthdate, height, weight, etc.) and their fitness goal. It then uses the Mifflin-St Jeor equation to calculate their personalized daily targets for calories and macros, saving all this information as custom attributes in the user's **Amazon Cognito** profile.

#### `GetUserProfile.py`
* **Trigger:** API Gateway (`GET /profile`)
* **Responsibility:** When a user opens the app, this function is called to fetch their complete profile. It retrieves all standard and custom attributes from **Amazon Cognito**, formats them into a clean JSON object (handling cases where attributes may not exist yet), and returns it to the app to populate the dashboard.

---

### 2. Asynchronous AI Analysis Workflow

This is the core workflow of our application, designed to be non-blocking and highly scalable.

#### `UploadImage.py`
* **Trigger:** API Gateway (`GET /upload-url`)
* **Responsibility:** To ensure security and efficiency, our app never uploads images through our backend. Instead, it calls this function first. The Lambda generates a secure, temporary **S3 Pre-signed URL** that grants write access to a specific, unique path in our S3 bucket. This URL is returned to the app.

#### `RequestAnalysis.py`
* **Trigger:** API Gateway (`POST /analyze`)
* **Responsibility:** After the app successfully uploads an image to S3, it calls this function. This Lambda's only job is to initiate the asynchronous workflow. It generates a unique `analysisId`, packages it with the S3 object key into a message, and sends it to an **Amazon SQS** queue. It then immediately returns the `analysisId` to the app.

#### `AnalyzeImage.py` (The "Worker")
* **Trigger:** Amazon SQS (receives messages from the analysis queue)
* **Responsibility:** This is our main AI processing engine. It runs in the background, completely decoupled from the user's app. When it receives a job from SQS, it:
    1.  Fetches the image from **S3**.
    2.  Calls **Amazon Bedrock**'s multimodal model with the image and a detailed prompt.
    3.  Receives the JSON analysis result from Bedrock.
    4.  Saves the final result to a **DynamoDB** table using the `analysisId` as the key.

#### `GetAnalysisResult.py`
* **Trigger:** API Gateway (`GET /analyze/{analysisId}`)
* **Responsibility:** While the analysis is processing, the app periodically calls this endpoint (polling). This simple Lambda function queries the **DynamoDB** table for an item with the given `analysisId`. If the item exists, it returns the full analysis result. If not, it returns a "PENDING" status.

---

### 3. Food Logging

These functions are responsible for the final step of saving and retrieving the user's confirmed food logs.

#### `SaveAnalysis.py`
* **Trigger:** API Gateway (`POST /food-logs`)
* **Responsibility:** After the user sees the AI analysis results and confirms a food choice, the app calls this function. It takes the final, user-approved data (food name, calories, macros, image URL, etc.) and saves it as a new item in our main food log table in **DynamoDB**.

#### `GetFoodlog.py`
* **Trigger:** API Gateway (`GET /food-logs`)
* **Responsibility:** This function fetches a list of previously saved food logs for a specific user from **DynamoDB**. It supports features like viewing today's meal history or retrieving records for the calendar view.

By breaking down our logic into these small, single-purpose Lambda functions, we have built a backend that is not only powerful but also easy to maintain, debug, and scale independently.


## 🛠️ Tech Stack

| Category      | Technology                                    |
| :------------ | :-------------------------------------------- |
| **Frontend** | Flutter                                       |
| **Backend** | AWS Lambda (Python), API Gateway (HTTP API)   |
| **AI Engine** | Amazon Bedrock (Anthropic Claude 3 Sonnet)    |
| **Database** | Amazon DynamoDB                               |
| **Storage** | Amazon S3                                     |
| **Auth** | Amazon Cognito                                |
| **Queue** | Amazon SQS                                    |

## ⚙️ Setup & Installation

This project is structured as a monorepo containing the frontend app and the backend services.

### 1. Backend Setup (lambda_backend/)

The backend consists of several AWS Lambda functions, managed via the AWS Management Console or SAM/Serverless Framework.

1.  **Prerequisites:** AWS Account, AWS CLI, Python 3.9+
2.  **Deploy Lambda Functions:** Each directory within `lambda_backend/` corresponds to a Lambda function. Deploy each function and configure its IAM role with the necessary permissions (S3, DynamoDB, SQS, Bedrock, Cognito).
3.  **Configure API Gateway:** Set up an HTTP API with the required routes (`/upload-url`, `/analyze`, etc.) and integrate them with the corresponding Lambda functions.
4.  **Set up Cognito & SQS:** Create a Cognito User Pool for authentication and an SQS Standard Queue for the asynchronous analysis workflow.
5.  **Environment Variables:** Configure the necessary environment variables for each Lambda function (e.g., `BUCKET_NAME`, `TABLE_NAME`, `SQS_QUEUE_URL`, `USER_POOL_ID`).

### 2. Frontend Setup (snapit/)

The frontend is a Flutter application.

1.  **Prerequisites:** Flutter SDK installed.
2.  **Navigate to the app directory:**
    ```bash
    cd flutter_app
    ```
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Configure API Endpoint:** Update the API endpoint URL in the app's configuration file to match your deployed API Gateway stage URL.
5.  **Run the app:**
    ```bash
    flutter run
    ```

---

## 👥 Team

* **Jeongtae Kim:** Developer (Backend, DevOps)
* **Hayoung Kim:** Designer & Planner
