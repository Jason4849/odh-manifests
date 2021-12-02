export access_key=$(radosgw-admin user info --uid=cn |jq .keys[0].access_key -r)
export secret_key=$(radosgw-admin user info --uid=cn |jq .keys[0].secret_key -r)

cat << EOF > s3test.py
import boto.s3.connection

access_key = '${access_key}'
secret_key = '${secret_key}'
conn = boto.connect_s3(
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        host='127.0.0.1', port=8000,
        is_secure=False, calling_format=boto.s3.connection.OrdinaryCallingFormat(),
       )

bucket = conn.create_bucket('my-new-bucket')
for bucket in conn.get_all_buckets():
    print "{name} {created}".format(
        name=bucket.name,
        created=bucket.creation_date,
    )
    
EOF

yum install python-boto -y
sleep 5
python s3test.py
