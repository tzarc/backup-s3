# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2021-08-31

- Use latest postgres client (v13)
- Postgres: dropdb before loading dump


## [1.3.0] - 2020-12-09

- Ignore tar warning "file changed as we read it"


## [1.2.0] - 2020-08-25

- Use latest postgres client (v12)


## [1.1.0] - 2020-08-18

- Fixed mysqldump error message which appeared with mysql 5.3.31:
  ```
  Error: 'Access denied; you need (at least one of) the PROCESS privilege(s) for this operation' when trying to dump tablespaces
  ```


## [1.0.0] - 2020-05-02

- Initial version
