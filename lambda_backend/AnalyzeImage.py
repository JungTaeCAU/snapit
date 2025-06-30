import json
import base64
import boto3
import os
from datetime import datetime, timezone

# Boto3 클라이언트 초기화
s3_client = boto3.client("s3")
bedrock_runtime = boto3.client("bedrock-runtime")
dynamodb = boto3.resource("dynamodb")

# Lambda 환경 변수에서 리소스 이름 가져오기
BUCKET_NAME = os.environ.get("BUCKET_NAME")
MODEL_ID = os.environ.get("MODEL_ID")
RESULTS_TABLE_NAME = os.environ.get(
    "RESULTS_TABLE_NAME"
)  # 새로 추가 (예: 'analysis-results')

# DynamoDB 테이블 객체 가져오기
results_table = dynamodb.Table(RESULTS_TABLE_NAME)
MAX_TOKENS = 1024


def run_multi_modal_prompt(image_bytes, prompt_text):
    """
    (이전 코드와 동일) Bedrock 멀티모달 모델을 호출합니다.
    """
    base64_image = base64.b64encode(image_bytes).decode("utf-8")
    message = {
        "role": "user",
        "content": [
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64_image,
                },
            },
            {"type": "text", "text": prompt_text},
        ],
    }
    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": MAX_TOKENS,
        "messages": [message],
    }
    try:
        response = bedrock_runtime.invoke_model(
            modelId=MODEL_ID, body=json.dumps(request_body)
        )
        response_body = json.loads(response.get("body").read())
        return response_body.get("content", [{}])[0].get("text", "")
    except Exception as e:
        print(f"Error invoking Bedrock model: {e}")
        raise


def lambda_handler(event, context):
    """
    SQS 메시지를 트리거로 받아 이미지 분석을 수행하고, 결과를 DynamoDB에 저장합니다.
    """
    # SQS는 여러 개의 메시지를 'Records' 리스트에 담아 전달할 수 있습니다.
    for record in event.get("Records", []):
        try:
            # 1. SQS 메시지 Body를 파싱하여 작업 정보 추출
            message_body = json.loads(record["body"])
            analysis_id = message_body.get("analysisId")
            object_key = message_body.get("objectKey")

            if not analysis_id or not object_key:
                print(f"Skipping invalid message: {record['body']}")
                continue

            print(f"Processing analysis job: {analysis_id} for object: {object_key}")

            # 2. S3에서 이미지 가져오기
            s3_object = s3_client.get_object(Bucket=BUCKET_NAME, Key=object_key)
            image_bytes = s3_object["Body"].read()

            # 3. Bedrock에 전달할 프롬프트 정의 (이전과 동일)
            prompt = """
            You are a helpful nutrition analysis assistant.
            Your task is to analyze the provided meal image and identify the 3 most likely dishes. For each dish, provide an estimation for the following nutritional values:
            1. Total calories (in kcal).
            2. Protein (in grams).
            3. Carbohydrates (in grams).
            4. Fat (in grams).

            Output Rules:
            - You must respond with Raw JSON only. Do not include ```json```, markdown, or any surrounding text or explanations.
            - The JSON must follow the exact structure shown in the example below.
            - For the 'name' field, capitalize the first letter of each word (e.g., 'Chicken Breast Salad').

            Example JSON Structure:
            {"candidates": [
                {"name": "Dish Name 1", "calories": 550, "protein": 25, "carbs": 60, "fat": 23},
                {"name": "Dish Name 2", "calories": 600, "protein": 30, "carbs": 55, "fat": 28},
                {"name": "Dish Name 3", "calories": 500, "protein": 20, "carbs: 70, "fat": 16}
            ]}
            """

            # 4. Bedrock을 호출하여 AI 분석 수행
            analysis_result_str = run_multi_modal_prompt(image_bytes, prompt)

            # Bedrock이 반환한 JSON 문자열을 파이썬 객체로 변환
            analysis_data = json.loads(analysis_result_str)

            # 5. DynamoDB에 저장할 아이템 구성
            timestamp = datetime.now(timezone.utc).isoformat()

            item_to_save = {
                "analysisId": analysis_id,  # 파티션 키
                "status": "COMPLETED",  # 분석 상태
                "result": analysis_data,  # 분석 결과 (JSON 객체)
                "objectKey": object_key,  # 원본 이미지 키
                "updatedAt": timestamp,
            }

            # 6. DynamoDB에 결과 저장
            results_table.put_item(Item=item_to_save)
            print(f"Successfully saved analysis result for {analysis_id} to DynamoDB.")

        except Exception as e:
            # 개별 메시지 처리 중 에러 발생 시 로그를 남기고 다음 메시지로 넘어갑니다.
            # 에러 발생 시 SQS가 재시도하도록 하려면 여기서 에러를 다시 raise 해야 합니다.
            print(f"Failed to process message {record.get('messageId')}. Error: {e}")
            # raise e # 재시도하려면 이 줄의 주석을 해제

    return {"statusCode": 200, "body": json.dumps("Processing complete.")}
