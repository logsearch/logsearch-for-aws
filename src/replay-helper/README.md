Sometimes, you might want to backfill or replay old data into your queue. Here's an example of enumerating a day of files and replaying them into the queue so the `s3-notification` job picks them up again.

Before starting, define some configuration values...

    $ export BACKFILL_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/${AWS_ACCOUNT_ID}/l4aws-cloudtrail"
    $ export BACKFILL_BUCKET="example-aws-logs-us-east-1"
    $ export BACKFILL_DATE="2015/01/01"

Next, you'll want to get the list of files you'll be replaying...

    $ aws s3api list-objects \
      --bucket="${BACKFILL_BUCKET}" \
      --prefix="AWS/CloudTrail/AWSLogs/${AWS_ACCOUNT_ID}/CloudTrail/${AWS_DEFAULT_REGION}/${BACKFILL_DATE}" \
      > tmp-replay-$$.json

Then, `cat` the results into the appropriate helper script based on the job you're using...

    $ cat tmp-replay-$$.json | ./bin/s3-notification

Once finished, you can remove the temporary results...

    $ rm tmp-replay-$$.json

It may take some time before everything finishes processing.
