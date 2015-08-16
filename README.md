# logsearch-for-aws

A BOSH release to help you ingest, parse, and visualize your AWS logs.


## About

We can currently handle these log types...

 * [Billing](http://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/detailed-billing-reports.html)
 * [CloudTrail](http://aws.amazon.com/cloudtrail/)
 * [S3 Server Logs](http://docs.aws.amazon.com/AmazonS3/latest/dev/ServerLogs.html)

We rely a process flow which looks like...

  0. AWS dumps a new log into your S3 bucket
  0. Your S3 bucket sends a notification to a SQS topic about it
  0. The `s3-notification` job waits for messages on that SQS topic
  0. It downloads the log file from S3 and normalizes the contents
  0. Events get pushed into the redis queue
  0. Your regular logsearch cluster takes care of the rest

We like this setup because...

  * can continue adding support for all the AWS log formats
  * can reuse our existing logsearch infrastructure for parsing and searching log events
  * using a queue is much more scalable than watching entire bucket paths for new files


## Usage

Before getting started, you must set up the following in AWS...

  * IAM credentials which allow working off the queue and downloading the referenced S3 files ([sample](./src/aws-helper/iam/sample-policy.json))
  * Separate SQS Queues and S3 Notifications for the log types and files you use ([sample](./src/aws-helper/s3-sns-sqs/))

Fetch and install our logsearch configuration ([details](#@todo))...

    $ wget -O- https://logsearch-for-aws-boshrelease.s3.amazonaws.com/release/latest/logsearch-config.tgz | tar -xz
    $ open \
      logsearch-config/logs/elasticsearch-mappings.json \
      logsearch-config/logs/logstash-filters.conf
    ...snip...

Upload the release to your director...

    $ bosh upload release https://logsearch-for-aws-boshrelease.s3.amazonaws.com/release/latest/tarball.tgz

Update your deployment to add the release, templates, and properties...

    releases:
      ...snip...
      - name: "logsearch-for-aws"
        version: "latest"
    jobs:
      - name: "l4aws"
        templates:
          ...snip...
          - release: "logsearch-for-aws"
            name: "s3-notification"
    properties:
      ...snip...
      l4aws:
        access_key_id:     "...snip..."
        secret_access_key: "...snip..."
        s3_notification:
          queues:
            # [ queue region , queue name         , log format type ]
            - [ "us-east-1"  , "l4aws-billing"    , "billing"       ]
            - [ "us-east-1"  , "l4aws-cloudtrail" , "cloudtrail"    ]
            - [ "us-east-1"  , "l4aws-s3"         , "s3"            ]


## Implementing a New Log Type

If you want to add parsing for a new log type... here are the things you should keep in mind...

 0. Update `s3-notification` job templates...
     1. `config/logstash.conf.erb` - add it to the list used to create `file` inputs
     1. `bin/main_ctl` - add it to the list used to `mkdir` directories
     1. `logsearch/logs.yml` - add a dummy entry to ensure the logsearch-config reference is active
 0. Create `src/scripts/transform-{aws-log-format-name}` which will convert the raw S3 log file format into a single event per line.
 0. Implement the filtering configuration in `src/logsearch-config/logs/{aws-log-format-name}`...
     1. Write `{aws-log-format-name}` to `name`
     1. Write your test data and expectations to `expected.testdata`
     1. Write your logstash filter configurations to `logstash-filters.conf`
     1. Write your elasticsearch mapping configurations to `elasticsearch-mapping.json`
 0. Update `src/aws-helper/s3-sns-sqs/generator/regenerate.sh` (and then execute) to add the new log type.
 0. Update `src/aws-helper/iam/sample-policy.json` to add the new sample directory (if applicable).
 0. Update `README.md` to add the log file format to our list of supported logs.

Once updated, run `./bin/logsearch-config` to test your log parsing filters and generate new configuration in `./logsearch-config`. Use those configuration files in your test environment and verify your new log runs through the whole process.

Share your work with a Pull Request :)


## Additional Resources

 * [Replay Helper](./src/replay-helper) - (fairly) easy way to replay some old logs into the queues for re-analysis


## License

[Apache License 2.0](./LICENSE)
