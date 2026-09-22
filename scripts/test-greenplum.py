#!/usr/bin/env python3
"""Run a small, read-only connectivity test against PSG Greenplum."""

import argparse
import getpass
import json
import os
import sys

import psycopg2


class CredentialError(RuntimeError):
    """Raised when database credentials cannot be resolved safely."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--host",
        default=os.getenv("PGHOST", "gpdb-priv.preyrasolutions.com"),
    )
    parser.add_argument("--port", type=int, default=int(os.getenv("PGPORT", "5432")))
    parser.add_argument("--database", default=os.getenv("PGDATABASE", "psg"))
    parser.add_argument("--user", default=os.getenv("PGUSER", "readonly_user"))
    parser.add_argument(
        "--secret-id",
        default=os.getenv("PGSECRET_ID"),
        help="Retrieve username/password JSON from this Secrets Manager secret.",
    )
    parser.add_argument(
        "--aws-region",
        default=os.getenv(
            "AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "ca-central-1")
        ),
        help="AWS Region containing --secret-id (default: ca-central-1).",
    )
    parser.add_argument(
        "--prompt-password",
        action="store_true",
        help="Prompt even when PGPASSWORD or --secret-id is available.",
    )
    return parser.parse_args()


def password_from_secret(secret_id: str, region: str, expected_user: str) -> str:
    try:
        import boto3
        from botocore.exceptions import BotoCoreError, ClientError
    except ImportError as error:
        raise CredentialError(
            "Boto3 is required only for --secret-id; install the aws optional "
            "dependency or omit --secret-id to use the password prompt."
        ) from error

    try:
        response = boto3.client("secretsmanager", region_name=region).get_secret_value(
            SecretId=secret_id
        )
    except (BotoCoreError, ClientError) as error:
        raise CredentialError(
            f"Could not retrieve Secrets Manager secret {secret_id!r}: {error}"
        ) from error

    secret_string = response.get("SecretString")
    if not secret_string:
        raise CredentialError(f"Secret {secret_id!r} has no SecretString value.")

    try:
        secret = json.loads(secret_string)
        secret_user = secret.get("user") or secret.get("username")
        password = secret["password"]
    except (AttributeError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise CredentialError(
            f"Secret {secret_id!r} must be JSON with user (or username) and "
            "password fields."
        ) from error

    if not isinstance(secret_user, str) or not secret_user:
        raise CredentialError(
            f"Secret {secret_id!r} has no valid user or username field."
        )
    if secret_user != expected_user:
        raise CredentialError(
            f"Secret username {secret_user!r} does not match requested user "
            f"{expected_user!r}."
        )
    if not isinstance(password, str) or not password:
        raise CredentialError(f"Secret {secret_id!r} has an invalid password field.")

    return password


def resolve_password(args: argparse.Namespace) -> str:
    if args.prompt_password:
        return getpass.getpass(f"Password for {args.user}@{args.host}: ")

    password = os.getenv("PGPASSWORD")
    if password:
        return password

    if args.secret_id:
        return password_from_secret(args.secret_id, args.aws_region, args.user)

    return getpass.getpass(f"Password for {args.user}@{args.host}: ")


def main() -> int:
    args = parse_args()
    try:
        password = resolve_password(args)
    except CredentialError as error:
        print(f"Credential resolution failed: {error}", file=sys.stderr)
        return 2

    try:
        with psycopg2.connect(
            host=args.host,
            port=args.port,
            dbname=args.database,
            user=args.user,
            password=password,
            connect_timeout=5,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT version()")
                print(f"Server: {cursor.fetchone()[0]}")

                cursor.execute("SELECT current_database(), current_user")
                database, user = cursor.fetchone()
                print(f"Connected: database={database} user={user}")

                cursor.execute(
                    """
                    SELECT count(*)
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                      AND table_type = 'BASE TABLE'
                    """
                )
                print(f"Public base tables visible: {cursor.fetchone()[0]}")

                cursor.execute(
                    """
                    SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                      AND table_type = 'BASE TABLE'
                    ORDER BY table_name
                    LIMIT 20
                    """
                )
                tables = [row[0] for row in cursor.fetchall()]
                print("First public tables:")
                for table in tables:
                    print(f"  - {table}")
    except psycopg2.Error as error:
        print(f"Greenplum connection/query failed: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
