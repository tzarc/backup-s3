backup-s3
=========

__backup-s3__ periodically backs up a database (postgres or mysql) and/or data folder(s) to Amazon S3. Backups can be restored with a single command.

The typical use case is to back up an application (e.g. Wordpress) run with docker-compose.

![backup-s3.png](https://bitbucket.org/hleroy/backup-s3/raw/67be5a9d7b52717f70dbe7653c8f51ce00ce789d/backup-s3.png)


Setup with docker-compose
-------------------------

Add backup-s3 to your compose file. This is an example to backup a Wordpress container:

```yaml
  backup:
    image: hleroy/backup-s3
    volumes:
      - wordpress:/var/www/html  # Volume to back up
    environment:    # Provide env secrets (S3 key etc...)
      # S3
      S3_REGION: eu-central-1
      S3_BUCKET: my-bucket
      S3_ACCESS_KEY_ID: access_key_id
      S3_SECRET_ACCESS_KEY: secret_access_key
      # Database
      DB_ENGINE: mysql
      DB_NAME: wordpress
      DB_USER: wordpress
      DB_PASS: wordpress
      DB_HOST: mysql
      DB_PORT: 5432
      # Data
      DATA_PATH: '/var/www/html' # Customize to your needs
      # Cron schedule
      CRON_SCHEDULE: '0 0 * * *' # Every day at midnight
```

`DB_ENGINE` can be `mysql` or `postgres`. If omitted, no database backup is attempted.
`DB_PORT` is optional. It defaults to 3306 (for mysql) or 5432 (for postgres).

`DATA_PATH` must be an absolute path with no trailing slash. If omitted, no data backup is attempted. It is possible to specify multiple paths separated by a colon (:), e.g. ```DATA_PATH: '/var/www/html/images:/var/www/html/extensions:/var/www/data'```

`CRON_SHEDULE` uses the usual cron format. Try https://crontab.guru/ to customize to your needs.


Usage
-----

When your Compose application is started, backup will be run according to the CRON schedule.

Backup filenames have a timestamp and an appended random string.
E.g.  `2020-04-22T00:00:01Z.87793a5e1556e0ff8a8b528328fab4ad.tgz`

You can run an immediate backup by running:
`docker-compose run --rm backup no-cron`

You can restore a specific backup by running:
`docker-compose run --rm backup restore BACKUP_FILENAME`

Note: you must provide `BACKUP_FILENAME` without the file extension, e.g. `2020-04-22T00:00:01Z.87793a5e1556e0ff8a8b528328fab4ad`


Full example
------------

A complete docker-compose example for Wordpress (docker-compose-wp-example.yml) is available in the repository.

1. Open `docker-compose-wp-example.yml` and enter your S3 region, bucket and credentials
2. Run it with `docker-compose -f docker-compose-wp-example.yml up -d`
3. Open http://localhost:8080 in your browser and set up Wordpress.
4. See backup happening every 15 minutes in the logs: `docker-compose -f docker-compose-wp-example.yml logs --follow`
5. Force an immediate backup: `docker-compose -f docker-compose-wp-example.yml run --rm backup no-cron`
6. Mess with Wordpress...
7. Go to your AWS S3 console to pick up the latest backup filename
8. Restore your backup: `docker-compose -f docker-compose-wp-example.yml run --rm backup restore BACKUP_FILENAME`
9. Check that your backup is restored: http://localhost:8080


Security notes
--------------

To ensure your backup confidentiality, you should enable [Amazon S3 Block Public Access](https://aws.amazon.com/fr/s3/features/block-public-access/) feature.

If an attacker has compromised your container, your data is compromised but at least you should make sure he can't delete your backups. To do so, create an IAM strategy for the backup account to authorize __only put and get__ (but not list)
e.g.
```yaml
{
    "Version": "2012-10-17",
    "Statement": {
        "Effect": "Allow",
        "Action": [
            "s3:GetObject",
            "s3:PutObject"
        ],
        "Resource": [
            "arn:aws:s3:::your-bucket-1/*",
            "arn:aws:s3:::your-bucket-2/*",
            "arn:aws:s3:::your-bucket-3/*"
        ]
    }
}
```

Each backup file is appended a random string for uniqueness purposes. The random string makes the filename unguessable by an attacker, were the container compromised.  Thus, by limiting the S3 account permissions to put and get (but not list), the attacker couldn't overwrite old backup files.
