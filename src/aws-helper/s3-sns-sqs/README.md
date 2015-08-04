Included is a fairly simple CloudFormation template which sets up a SNS Topic configured to forward to a SQS Queue, both of which are configured with bucket policies to receive messages from your log bucket and respective topic.

You might find it useful for typical requirements (or at least a starting point).


# Usage

Before starting, define some configuration values...

    # what bucket has the logs you're monitoring?
    $ export BUCKET_NAME=example-aws-logs
    
    # what prefix should we use for all the topics and queues?
    $ export CONTEXT_NAME=l4aws-
    
    # we'll be creating a template; what should its name be?
    $ export TEMPLATE_NAME=${CONTEXT_NAME}-s3-sns-sqs
    
First, use the template to create topics and queues for the different log formats...

    $ aws cloudformation create-stack \
      --stack-name "${TEMPLATE_NAME}" \
      --template-body "file:///$PWD/cloudformation.json" \
      --parameters \
        ParameterKey=BucketName,ParameterValue=${BUCKET_NAME} \
        ParameterKey=ContextName,ParameterValue=${CONTEXT_NAME}

Wait for it to finish creation, then load up the results into some environment variables we can reuse.

    $ eval $(
        aws cloudformation describe-stack-resources \
        --stack-name "${TEMPLATE_NAME}" \
        | jq -r '.StackResources[] | "export CFN_" + .LogicalResourceId + "=" + .PhysicalResourceId + " ; "'
      )

Now you can use the newly created SNS topics to register event notifications on your logging bucket. For example...

    # actually, you can't do this automatically because awscli doesn't accept the Filter setting in this call yet
    # until then, do this manually
    $ aws s3api put-bucket-notification \
      --bucket "${BUCKET_NAME}" \
      --notification-configuration "{
        \"TopicConfiguration\": {
          \"Event\": \"s3:ObjectCreated:Put\",
          \"Filter\": {
            \"S3Key\": [
              {
                \"FilterRule\": {
                  \"Name\": \"prefix\",
                  \"Value\": \"AWSLogs/${AWS_ACCOUNT_ID}/CloudTrail/\"
                }
              }
            ]
          },
          \"Topic\": \"${CFN_cloudtrailSns}\"
        }
      }"
