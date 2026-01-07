# Backend services

## N8n

Set up database:

```sql
CREATE DATABASE n8n;
CREATE USER n8n WITH PASSWORD '********';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
-- change to the n8n database
GRANT ALL ON SCHEMA public TO n8n;
```
