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

## 🔬 AWS Lambda를 이렇게 사용했습니다.

저희는 서버를 직접 관리하는 대신, 각 Lambda 함수가 작고 독립적인 하나의 기능만을 담당하는 '마이크로서비스' 방식으로 접근했습니다. 덕분에 저희 시스템은 높은 확장성과 안정성을 갖추면서도 비용 효율적으로 운영될 수 있습니다.

각 Lambda 함수가 어떤 역할을 하는지 저희 코드와 API 구조에 맞춰 상세하게 설명해 드리겠습니다.

### 1. 사용자 프로필과 온보딩

사용자 경험을 개인화하는 데 필수적인 데이터 생성과 조회를 담당합니다.

#### `UpdateOnboardingProfile.py`
* **트리거:** `PATCH /profile` API
* **역할:** 신규 사용자가 처음 프로필을 설정할 때 호출됩니다. 사용자의 개인 정보(생년월일, 키, 몸무게 등)와 목표를 입력받아, 미플린-지어 방정식을 통해 개인에게 최적화된 일일 목표 칼로리와 영양소를 계산합니다. 그리고 이 모든 정보를 Amazon Cognito 프로필에 커스텀 속성으로 안전하게 저장합니다.

#### `GetUserProfile.py`
* **트리거:** `GET /profile` API
* **역할:** 사용자가 앱을 열 때 호출되어 전체 프로필을 가져옵니다. Amazon Cognito에서 모든 표준 및 커스텀 속성을 검색하고, (속성이 아직 존재하지 않는 경우까지 처리하여) JSON 객체로 포맷한 뒤, 대시보드 및 기타 UI 요소를 채우기 위해 앱으로 반환합니다.

### 2. 비동기 AI 분석 워크플로우

서비스의 핵심 로직입니다.

#### `UploadImage.py`
* **트리거:** `GET /upload-url` API
* **역할:** 보안과 효율성을 위해, 앱은 백엔드를 통해 이미지를 직접 업로드하지 않습니다. 대신, 이 함수를 먼저 호출하여 S3 버킷의 특정 경로에만 쓰기 권한을 부여하는 안전한 임시 **S3 Pre-signed URL**을 발급받습니다.

#### `RequestAnalysis.py`
* **트리거:** `POST /analyze` API
* **역할:** 앱이 S3에 이미지 업로드를 성공적으로 마친 후 이 함수를 호출합니다. 이 Lambda의 역할은 비동기 분석 작업을 시작시키는 것입니다. 고유한 `analysisId`를 생성하고, 이를 S3 객체 키와 함께 **Amazon SQS** 대기열로 보냅니다. 그런 다음 즉시 `analysisId`를 앱에 반환하여 사용자가 기다리지 않게 합니다.

#### `AnalyzeImage.py` (Worker)
* **트리거:** Amazon SQS (분석 큐로부터 메시지 수신)
* **역할:** 사용자의 앱과 완전히 분리되어 백그라운드에서 실행됩니다. SQS로부터 작업을 받으면, S3에서 이미지를 가져와 Amazon Bedrock의 멀티모달 모델을 호출하여 분석하고, 최종 결과를 `analysisId`와 함께 DynamoDB 테이블에 저장합니다.

#### `GetAnalysisResult.py`
* **트리거:** `GET /analyze/{analysisId}` API
* **역할:** 분석이 처리되는 동안, 앱은 주기적으로 이 엔드포인트를 호출(폴링)합니다. 이 Lambda는 주어진 `analysisId`로 DynamoDB 테이블에서 분석 결과를 조회하여, 결과가 있으면 반환하고 없으면 "처리 중" 상태를 알려줍니다.

### 3. 음식 기록 관리

사용자가 확인한 최종 식단 기록을 저장하고 조회합니다.

#### `SaveAnalysis.py`
* **트리거:** `POST /food-logs` API
* **역할:** 사용자가 AI 분석 결과를 보고 최종적으로 음식을 선택하면 호출됩니다. 사용자가 승인한 모든 데이터(음식 이름, 칼로리, 영양소, 이미지 URL 등)를 메인 음식 기록 테이블인 DynamoDB에 저장합니다.

#### `GetFoodlog.py`
* **트리거:** `GET /food-logs` API
* **역할:** 특정 사용자의 이전 식단 기록 목록을 DynamoDB에서 가져옵니다. 오늘의 식사 기록을 보거나 캘린더 뷰를 위한 데이터를 조회하는 기능을 지원합니다.

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
