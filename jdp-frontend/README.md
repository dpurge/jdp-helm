# Frontend services

## Planka

Set up database:

```sql
CREATE DATABASE planka;
CREATE USER planka WITH PASSWORD '********';
GRANT ALL PRIVILEGES ON DATABASE planka TO planka;
-- change to the planka database: \connect planka
GRANT USAGE, CREATE ON SCHEMA public TO planka;
```
