# Backend services

## N8n

```sql
CREATE DATABASE n8n;
CREATE USER n8n-user WITH PASSWORD 'n8n';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
-- change to the n8n database
GRANT ALL ON SCHEMA public TO n8n;
```
