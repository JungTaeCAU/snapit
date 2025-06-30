<div align="left">
  <b><a href="README.md">🇺🇸 English</a></b>
</div>

# Snapit: AI 기반 식단 관리 앱

**Just Snap It. We'll Log It.** Snapit은 음식 사진을 찍기만 하면, AI가 단 몇 초 만에 이미지를 분석하여 정확한 영양 정보를 제공하는 혁신적인 식단 관리 앱입니다.

본 프로젝트는 **2025 AWS Lambda 해커톤** 출품작입니다.

---

## 🚀 라이브 데모 (Live Demo)

[Snapit 데모 영상](https://youtu.be/ksLz942HZTM)

## ✨ 주요 기능 (Key Features)

* **Snap, Tap, Log:** 사진 찍고, AI 제안을 탭하고, 기록하는 3초 완성 프로세스
* **정확한 AI 분석:** Amazon Bedrock의 멀티모달 AI를 활용하여 음식의 전체 맥락을 이해하고 신뢰도 높은 영양 정보를 제공합니다.
* **개인 맞춤형 목표 설정:** 온보딩 시 입력한 개인 프로필과 목표에 따라 AI가 일일 권장 섭취량을 자동으로 계산하고 설정해 줍니다.
* **비동기 및 확장성:** SQS를 사용한 비동기 아키텍처를 기반으로 하여, 끊김 없고 안정적인 사용자 경험을 제공합니다.

## 🏛️ 시스템 아키텍처 (System Architecture)

Snapit 애플리케이션 전체는 100% 서버리스 아키텍처로 AWS 위에 구축되었습니다.
<img width="2400" alt="Snapit Backend" src="https://github.com/user-attachments/assets/dfdaebaa-6628-4ce9-aae3-046d9180fa5f" />

## 🛠️ 기술 스택 (Tech Stack)

| 구분 | 기술 |
| :--- | :--- |
| **프론트엔드** | Flutter |
| **백엔드** | AWS Lambda (Python), API Gateway (HTTP API) |
| **AI 엔진** | Amazon Bedrock (Anthropic Claude 4 Sonnet) |
| **데이터베이스** | Amazon DynamoDB |
| **스토리지** | Amazon S3 |
| **인증** | Amazon Cognito |
| **메시지 큐** | Amazon SQS |

## ⚙️ 설정 및 설치 방법 (Setup & Installation)

이 프로젝트는 프론트엔드 앱과 백엔드 서비스를 하나의 리포지토리에서 관리하는 모노리포(Monorepo) 구조입니다.

### 1. 백엔드 설정 (lambda_backend/)

백엔드는 여러 개의 AWS Lambda 함수로 구성되어 있으며, AWS Management Console 또는 SAM/Serverless Framework를 통해 관리됩니다.

1.  **사전 준비물:** AWS 계정, AWS CLI, Python 3.12+
2.  **Lambda 함수 배포:** `lambda_backend/` 폴더 안의 각 디렉토리는 개별 Lambda 함수에 해당합니다. 각 함수를 배포하고, 필요한 권한(S3, DynamoDB, SQS, Bedrock, Cognito)을 가진 IAM 역할을 설정합니다.
3.  **API Gateway 설정:** HTTP API를 생성하고 필요한 라우트(`/upload-url`, `/analyze` 등)를 설정한 뒤, 각 라우트를 해당하는 Lambda 함수와 통합합니다.
4.  **Cognito & SQS 설정:** 사용자 인증을 위한 Cognito User Pool과 비동기 분석 워크플로우를 위한 SQS 표준 대기열(Standard Queue)을 생성합니다.
5.  **환경 변수 설정:** 각 Lambda 함수에 필요한 환경 변수(예: `BUCKET_NAME`, `TABLE_NAME`, `SQS_QUEUE_URL`, `USER_POOL_ID`)를 설정합니다.

### 2. 프론트엔드 설정 (flutter_app/)

프론트엔드는 Flutter 애플리케이션입니다.

1.  **사전 준비물:** Flutter SDK 설치
2.  **앱 디렉토리로 이동:**
    ```bash
    cd flutter_app
    ```
3.  **의존성 패키지 설치:**
    ```bash
    flutter pub get
    ```
4.  **API 엔드포인트 설정:** 앱의 설정 파일에서 API 엔드포인트 주소를 배포된 API Gateway의 URL로 업데이트합니다.
5.  **앱 실행:**
    ```bash
    flutter run
    ```

---

## 👥 팀원 (Team)

* **김정태:** 개발자 (Backend, DevOps)
* **김하영:** 디자이너 & 기획자
