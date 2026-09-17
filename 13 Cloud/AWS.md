#cloud

## S3 bucket enumeration
If you spot an S3 bucket + region in a URL, try listing it anonymously before assuming it's locked down:
```bash
aws s3 ls s3://bucket-name/ --region <region> --no-sign-request
```
If that returns files, pull them down:
```bash
aws s3 cp s3://bucket-name/filename . --region <region> --no-sign-request
```
`--no-sign-request` skips authentication entirely — this only works because the bucket allows anonymous access. Costs nothing to check, and catches a surprising number of real misconfigurations.
