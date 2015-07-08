# Just in case...

You want to setup an IAM user with a policy...

    {
      "Statement": [
        {
          "Action": [
            "sqs:ReceiveMessage",
            "sqs:GetQueueUrl",
            "sqs:DeleteMessage"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:sqs:us-east-1:123456789012:example-l4aws"
          ],
          "Sid": "SQS"
        },
        {
          "Action": [
            "s3:GetObject"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:s3:::example-aws-cloudtrail-us-east-1/AWS/CloudTrail/AWSLogs/123456789012/CloudTrail/us-east-1/*"
          ],
          "Sid": "S3"
        }
      ],
      "Version": "2012-10-17"
    }


You need to upgrade packages from the main logsearch-boshrelease...

    LOGSEARCH_DIR="../../logsearch/logsearch-boshrelease"
    PACKAGES="java7 logstash"
    for PACKAGE in $PACKAGES ; do bosh-gen extract-pkg "${LOGSEARCH_DIR}/packages/${PACKAGE}" ; done


You want to backfill CloudTrail logs for a particular date (load your `AWS_` env first)...

    BACKFILL_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/${AWS_ACCOUNT_ID}/example-l4aws"
    BACKFILL_BUCKET="example-aws-cloudtrail-us-east-1"
    BACKFILL_DATE="2015/01/01"

    mkdir tmp-backfill-$$
    aws s3api list-objects \
      --bucket="${BACKFILL_BUCKET}" \
      --prefix="AWS/CloudTrail/AWSLogs/${AWS_ACCOUNT_ID}/CloudTrail/${AWS_DEFAULT_REGION}/${BACKFILL_DATE}" \
      | jq -c \
        --arg BUCKET "${BACKFILL_BUCKET}" \
        '.Contents[] | {
          "Id" : .ETag | fromjson,
          "MessageBody" : { 
            "Message" : {
              "s3Bucket" : $BUCKET,
              "s3ObjectKey" : [ .Key ]
            } | tostring
          } | tostring
        }' \
        | ( cd tmp-backfill-$$ ; split -l 10 )
    for CHUNK in $( find tmp-backfill-$$ -type f ) ; do
      aws sqs send-message-batch --queue-url "${BACKFILL_QUEUE_URL}" --entries "$( cat ${CHUNK} | jq --slurp -r '. | tostring' )"
    done
    rm -fr backfill-$$
