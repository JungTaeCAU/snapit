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
