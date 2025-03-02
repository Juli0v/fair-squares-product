// server.js
const express = require('express');
const bodyParser = require('body-parser');
const { Client } = require('pg');

const app = express();
app.use(bodyParser.json());

// Configuration de la connexion PostgreSQL
const pgClient = new Client({
  host: 'db',         // Ici 'db' correspond au nom du service défini dans docker-compose (si conteneurisé)
  port: 5432,
  user: 'postgres',
  password: 'postgres',
  database: 'fs-postgres-prod'
});

pgClient.connect()
  .then(() => console.log("Connecté à PostgreSQL"))
  .catch(err => console.error("Erreur de connexion PostgreSQL:", err));

// Route pour recevoir l'événement
app.post('/events', async (req, res) => {
  const event = req.body;
  try {
    const query = `INSERT INTO events (session_id, event_type, event_timestamp, metadata, user_id)
                   VALUES ($1, $2, to_timestamp($3), $4, $5)`;
    await pgClient.query(query, [
      event.session_id,
      event.event_type,
      event.event_timestamp,
      JSON.stringify(event.metadata),
      event.user_id
    ]);
    res.status(200).send({ status: "ok" });
  } catch (err) {
    console.error("Erreur lors de l'insertion dans la DB:", err);
    res.status(500).send({ error: err.message });
  }
});

// Démarrer le serveur sur le port 3000
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Microservice d'ingestion en écoute sur le port ${PORT}`);
});