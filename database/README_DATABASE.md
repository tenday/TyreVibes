# 🗄️ TyreVibes - Database Setup Guide

Guida completa per configurare il database TyreVibes con qualsiasi sistema SQL.

## 📋 Indice

1. [Opzioni Database](#opzioni-database)
2. [Setup MySQL/MariaDB](#setup-mysqlmariadb)
3. [Setup PostgreSQL](#setup-postgresql)
4. [Setup SQLite](#setup-sqlite)
5. [Backend REST API](#backend-rest-api)
6. [Configurazione iOS App](#configurazione-ios-app)

---

## 🎯 Opzioni Database

TyreVibes supporta **3 tipi di database SQL**:

| Database | File Schema | Quando Usarlo |
|----------|-------------|---------------|
| **MySQL/MariaDB** | `schema.sql` | ✅ Produzione, hosting condiviso, cPanel |
| **PostgreSQL** | `schema_postgresql.sql` | ✅ Produzione enterprise, Heroku, AWS RDS |
| **SQLite** | `schema_sqlite.sql` | ✅ Sviluppo locale, testing, app offline |

---

## 🔧 Setup MySQL/MariaDB

### Requisiti
- MySQL 8.0+ o MariaDB 10.5+
- PHP 7.4+ (per backend REST API)
- Apache/Nginx

### 1. Crea Database

```bash
# Accedi a MySQL
mysql -u root -p

# Crea database
CREATE DATABASE tyrevibes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Crea utente dedicato
CREATE USER 'tyrevibes_user'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON tyrevibes.* TO 'tyrevibes_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 2. Importa Schema

```bash
# Importa le tabelle
mysql -u tyrevibes_user -p tyrevibes < database/schema.sql

# Verifica tabelle create
mysql -u tyrevibes_user -p tyrevibes -e "SHOW TABLES;"
```

### 3. Verifica Installazione

```sql
-- Accedi al database
mysql -u tyrevibes_user -p tyrevibes

-- Controlla tabelle
SHOW TABLES;

-- Output atteso:
-- +-------------------------------+
-- | Tables_in_tyrevibes          |
-- +-------------------------------+
-- | image_uploads                 |
-- | tread_depth_measurements      |
-- | tyre_analyses                 |
-- | tyre_lifecycle_projections    |
-- | tyre_recommendations          |
-- | tyres_vehicles                |
-- | users                         |
-- | vehicles                      |
-- +-------------------------------+

-- Controlla viste
SHOW FULL TABLES WHERE table_type = 'VIEW';
```

---

## 🐘 Setup PostgreSQL

### Requisiti
- PostgreSQL 12+
- Node.js 16+ (per backend REST API)

### 1. Crea Database

```bash
# Accedi come postgres user
sudo -u postgres psql

# Crea database e utente
CREATE DATABASE tyrevibes;
CREATE USER tyrevibes_user WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE tyrevibes TO tyrevibes_user;

# Connetti al database
\c tyrevibes

# Abilita estensione UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
\q
```

### 2. Importa Schema

```bash
# Importa schema
psql -U tyrevibes_user -d tyrevibes -f database/schema_postgresql.sql

# Verifica tabelle
psql -U tyrevibes_user -d tyrevibes -c "\dt"
```

### 3. Configurazione Opzionale

```sql
-- Ottimizza per performance
ALTER DATABASE tyrevibes SET timezone TO 'Europe/Rome';

-- Abilita logging (per debug)
ALTER DATABASE tyrevibes SET log_statement TO 'all';
```

---

## 📱 Setup SQLite

### Requisiti
- SQLite 3.35+
- Python 3.8+ (per backend API Flask)

### 1. Crea Database

```bash
# Crea database e importa schema
sqlite3 tyrevibes.db < database/schema_sqlite.sql

# Verifica tabelle
sqlite3 tyrevibes.db ".tables"
```

### 2. Abilita Foreign Keys

```sql
-- Apri database
sqlite3 tyrevibes.db

-- Abilita foreign keys
PRAGMA foreign_keys = ON;

-- Verifica
PRAGMA foreign_keys;
-- Output: 1 (enabled)
```

### 3. Backup e Restore

```bash
# Backup
sqlite3 tyrevibes.db ".backup tyrevibes_backup.db"

# Restore
sqlite3 tyrevibes.db ".restore tyrevibes_backup.db"

# Export SQL
sqlite3 tyrevibes.db ".dump" > backup.sql
```

---

## 🌐 Backend REST API

L'app iOS comunica con il database tramite **API REST**. Scegli uno stack:

### Opzione 1: PHP + MySQL (Consigliato per Hosting Condiviso)

**Struttura**:
```
/api/
├── config.php          # Configurazione DB
├── v1/
│   ├── analyses/
│   │   ├── create.php  # POST /api/v1/analyses
│   │   ├── get.php     # GET /api/v1/analyses/{id}
│   │   ├── list.php    # GET /api/v1/analyses?tyre_id={id}
│   │   └── delete.php  # DELETE /api/v1/analyses/{id}
│   ├── projections/
│   │   ├── create.php  # POST /api/v1/projections
│   │   └── list.php    # GET /api/v1/projections?analysis_id={id}
│   └── auth/
│       ├── login.php   # POST /api/v1/auth/login
│       └── verify.php  # GET /api/v1/auth/verify
└── .htaccess           # URL rewriting
```

**Esempio config.php**:
```php
<?php
// config.php
define('DB_HOST', 'localhost');
define('DB_NAME', 'tyrevibes');
define('DB_USER', 'tyrevibes_user');
define('DB_PASS', 'your_password');
define('JWT_SECRET', 'your-super-secret-key-change-this');

try {
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false
        ]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed']);
    exit;
}
?>
```

**Esempio create.php**:
```php
<?php
// api/v1/analyses/create.php
header('Content-Type: application/json');
require_once '../../../config.php';

// Verifica autenticazione (JWT)
$headers = apache_request_headers();
if (!isset($headers['Authorization'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Leggi input JSON
$input = json_decode(file_get_contents('php://input'), true);

// Validazione input
$required = ['tyre_id', 'user_id', 'vehicle_id'];
foreach ($required as $field) {
    if (!isset($input[$field])) {
        http_response_code(400);
        echo json_encode(['error' => "Missing field: $field"]);
        exit;
    }
}

// Inserisci analisi
try {
    $stmt = $pdo->prepare("
        INSERT INTO tyre_analyses (
            id, tyre_id, user_id, vehicle_id, analysis_type,
            depth_front_left, depth_front_right, depth_rear_left, depth_rear_right,
            depth_average, depth_minimum,
            remaining_life_percentage, remaining_life_km, remaining_life_months,
            confidence_score,
            condition_front_left, condition_front_right, condition_rear_left, condition_rear_right,
            wear_pattern, wear_severity, notes
        ) VALUES (
            UUID(), :tyre_id, :user_id, :vehicle_id, :analysis_type,
            :depth_fl, :depth_fr, :depth_rl, :depth_rr,
            :depth_avg, :depth_min,
            :life_pct, :life_km, :life_months,
            :confidence,
            :cond_fl, :cond_fr, :cond_rl, :cond_rr,
            :wear_pattern, :wear_severity, :notes
        )
    ");

    $stmt->execute([
        ':tyre_id' => $input['tyre_id'],
        ':user_id' => $input['user_id'],
        ':vehicle_id' => $input['vehicle_id'],
        ':analysis_type' => $input['analysis_type'] ?? 'automatic',
        ':depth_fl' => $input['depth_front_left'] ?? null,
        ':depth_fr' => $input['depth_front_right'] ?? null,
        ':depth_rl' => $input['depth_rear_left'] ?? null,
        ':depth_rr' => $input['depth_rear_right'] ?? null,
        ':depth_avg' => $input['depth_average'] ?? null,
        ':depth_min' => $input['depth_minimum'] ?? null,
        ':life_pct' => $input['remaining_life_percentage'] ?? null,
        ':life_km' => $input['remaining_life_km'] ?? null,
        ':life_months' => $input['remaining_life_months'] ?? null,
        ':confidence' => $input['confidence_score'] ?? null,
        ':cond_fl' => $input['condition_front_left'] ?? null,
        ':cond_fr' => $input['condition_front_right'] ?? null,
        ':cond_rl' => $input['condition_rear_left'] ?? null,
        ':cond_rr' => $input['condition_rear_right'] ?? null,
        ':wear_pattern' => $input['wear_pattern'] ?? null,
        ':wear_severity' => $input['wear_severity'] ?? null,
        ':notes' => $input['notes'] ?? null
    ]);

    $analysisId = $pdo->lastInsertId();

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'id' => $analysisId,
        'message' => 'Analysis created successfully'
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}
?>
```

### Opzione 2: Node.js + PostgreSQL

**Pacchetti**:
```bash
npm install express pg cors dotenv jsonwebtoken bcryptjs
```

**Esempio server.js**:
```javascript
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Database connection
const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASS
});

app.use(cors());
app.use(express.json());

// POST /api/v1/analyses
app.post('/api/v1/analyses', async (req, res) => {
    const {
        tyre_id, user_id, vehicle_id, analysis_type,
        depth_front_left, depth_front_right, depth_rear_left, depth_rear_right,
        depth_average, depth_minimum,
        remaining_life_percentage, remaining_life_km, remaining_life_months,
        confidence_score,
        condition_front_left, condition_front_right, condition_rear_left, condition_rear_right,
        wear_pattern, wear_severity, notes
    } = req.body;

    try {
        const result = await pool.query(`
            INSERT INTO tyre_analyses (
                tyre_id, user_id, vehicle_id, analysis_type,
                depth_front_left, depth_front_right, depth_rear_left, depth_rear_right,
                depth_average, depth_minimum,
                remaining_life_percentage, remaining_life_km, remaining_life_months,
                confidence_score,
                condition_front_left, condition_front_right, condition_rear_left, condition_rear_right,
                wear_pattern, wear_severity, notes
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21
            ) RETURNING *
        `, [
            tyre_id, user_id, vehicle_id, analysis_type || 'automatic',
            depth_front_left, depth_front_right, depth_rear_left, depth_rear_right,
            depth_average, depth_minimum,
            remaining_life_percentage, remaining_life_km, remaining_life_months,
            confidence_score,
            condition_front_left, condition_front_right, condition_rear_left, condition_rear_right,
            wear_pattern, wear_severity, notes
        ]);

        res.status(201).json({
            success: true,
            data: result.rows[0]
        });
    } catch (error) {
        console.error('Error creating analysis:', error);
        res.status(500).json({
            error: 'Failed to create analysis'
        });
    }
});

// GET /api/v1/analyses/latest/:tyreId
app.get('/api/v1/analyses/latest/:tyreId', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT * FROM tyre_analyses
            WHERE tyre_id = $1
            ORDER BY analysis_date DESC
            LIMIT 1
        `, [req.params.tyreId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Analysis not found' });
        }

        res.json({ data: result.rows[0] });
    } catch (error) {
        console.error('Error fetching analysis:', error);
        res.status(500).json({ error: 'Failed to fetch analysis' });
    }
});

app.listen(port, () => {
    console.log(`TyreVibes API server listening on port ${port}`);
});
```

### Opzione 3: Python + Flask + SQLite

**Installazione**:
```bash
pip install flask flask-cors sqlite3
```

**Esempio app.py**:
```python
from flask import Flask, request, jsonify
import sqlite3
import uuid
from datetime import datetime

app = Flask(__name__)
DATABASE = 'tyrevibes.db'

def get_db():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/api/v1/analyses', methods=['POST'])
def create_analysis():
    data = request.json
    conn = get_db()

    analysis_id = str(uuid.uuid4())

    conn.execute('''
        INSERT INTO tyre_analyses (
            id, tyre_id, user_id, vehicle_id, analysis_type,
            depth_front_left, depth_front_right, depth_rear_left, depth_rear_right,
            depth_average, depth_minimum,
            remaining_life_percentage, remaining_life_km, remaining_life_months,
            confidence_score,
            condition_front_left, condition_front_right, condition_rear_left, condition_rear_right,
            wear_pattern, wear_severity, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        analysis_id,
        data['tyre_id'],
        data['user_id'],
        data['vehicle_id'],
        data.get('analysis_type', 'automatic'),
        data.get('depth_front_left'),
        data.get('depth_front_right'),
        data.get('depth_rear_left'),
        data.get('depth_rear_right'),
        data.get('depth_average'),
        data.get('depth_minimum'),
        data.get('remaining_life_percentage'),
        data.get('remaining_life_km'),
        data.get('remaining_life_months'),
        data.get('confidence_score'),
        data.get('condition_front_left'),
        data.get('condition_front_right'),
        data.get('condition_rear_left'),
        data.get('condition_rear_right'),
        data.get('wear_pattern'),
        data.get('wear_severity'),
        data.get('notes')
    ))

    conn.commit()
    conn.close()

    return jsonify({'success': True, 'id': analysis_id}), 201

if __name__ == '__main__':
    app.run(debug=True, port=5000)
```

---

## 📱 Configurazione iOS App

### 1. Aggiorna Api.plist

```xml
<key>BACKEND_BASE_URL</key>
<string>https://api.tuodominio.com</string>

<!-- oppure per sviluppo locale -->
<string>http://localhost:3000</string>
```

### 2. Il TyreAnalysisService Usa NetworkManager

Il service esistente (`TyreAnalysisService.swift`) è già predisposto per usare **NetworkManager**, che gestisce automaticamente:

✅ JWT Bearer token
✅ Header automatici
✅ Encoding/Decoding JSON
✅ Error handling

**Non serve modificare nulla!** NetworkManager usa già le API REST.

---

## 🔒 Sicurezza

### Best Practices

1. **JWT Authentication**: Usa JWT per autenticare ogni richiesta
2. **HTTPS Only**: Mai usare HTTP in produzione
3. **Input Validation**: Valida SEMPRE i dati in input
4. **SQL Injection**: Usa prepared statements
5. **Rate Limiting**: Limita richieste API (es. 100/min)
6. **CORS**: Configura CORS correttamente

### Esempio JWT (PHP)

```php
<?php
use Firebase\JWT\JWT;

function verifyToken() {
    $headers = apache_request_headers();
    $token = str_replace('Bearer ', '', $headers['Authorization'] ?? '');

    try {
        $decoded = JWT::decode($token, JWT_SECRET, ['HS256']);
        return $decoded;
    } catch (Exception $e) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid token']);
        exit;
    }
}
?>
```

---

## 📊 Testing

### Test Database

```bash
# MySQL
mysql -u tyrevibes_user -p tyrevibes -e "SELECT COUNT(*) FROM users;"

# PostgreSQL
psql -U tyrevibes_user -d tyrevibes -c "SELECT COUNT(*) FROM users;"

# SQLite
sqlite3 tyrevibes.db "SELECT COUNT(*) FROM users;"
```

### Test API

```bash
# Test creazione analisi
curl -X POST http://localhost:3000/api/v1/analyses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "tyre_id": 1,
    "user_id": "uuid-here",
    "vehicle_id": 1,
    "depth_front_left": 7.2,
    "depth_front_right": 7.0
  }'

# Test lettura analisi
curl http://localhost:3000/api/v1/analyses/latest/1 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 🚀 Deploy

### cPanel (MySQL + PHP)

1. Carica file in `public_html/api/`
2. Importa `schema.sql` via phpMyAdmin
3. Configura `config.php` con credenziali DB
4. Testa API: `https://tuodominio.com/api/v1/analyses`

### Heroku (PostgreSQL + Node.js)

```bash
heroku create tyrevibes-api
heroku addons:create heroku-postgresql:hobby-dev
heroku config:set JWT_SECRET=your-secret
git push heroku main
```

### AWS (RDS + Lambda)

1. Crea RDS PostgreSQL instance
2. Deploy API come Lambda function
3. Usa API Gateway per routing
4. Abilita VPC per sicurezza

---

## 📚 Risorse

- [MySQL Documentation](https://dev.mysql.com/doc/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [REST API Best Practices](https://restfulapi.net/)

---

**Versione**: 1.0
**Data**: 2025-11-17
**Autore**: TyreVibes Team
