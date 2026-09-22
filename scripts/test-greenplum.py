#!/usr/bin/env python3
"""Run a small, read-only connectivity test against PSG Greenplum."""

import argparse
import getpass
import os
import sys

import psycopg2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--host",
        default=os.getenv("PGHOST", "gpdb-priv.preyrasolutions.com"),
    )
    parser.add_argument("--port", type=int, default=int(os.getenv("PGPORT", "5432")))
    parser.add_argument("--database", default=os.getenv("PGDATABASE", "psg"))
    parser.add_argument("--user", default=os.getenv("PGUSER", "readonly_user"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    password = os.getenv("PGPASSWORD") or getpass.getpass(
        f"Password for {args.user}@{args.host}: "
    )

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
