from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Drop all database tables (for local dev reset only)."

    def handle(self, *args, **options):
        from django.db import connection

        tables = connection.introspection.table_names()
        with connection.cursor() as c:
            for t in tables:
                c.execute(f'DROP TABLE IF EXISTS "{t}" CASCADE;')
        self.stdout.write(f"✅  Dropped {len(tables)} tables.")
