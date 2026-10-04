/**
 * Somnius Community Stream Addon
 * Decoupled Stremio v3 protocol compliant server.
 * Can be hosted on Vercel, Cloudflare Workers, Node.js, or ElfHosted.
 */

const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
app.use(cors());

const MANIFEST = {
  id: "community.somnius.official",
  name: "Somnius Community Streams",
  version: "1.0.0",
  description: "Official decoupled community scraper add-on for Somnius. Aggregates multi-source 4K/1080p streams.",
  icon: "https://raw.githubusercontent.com/beratheon/Somnius/main/assets/icon.png",
  types: ["movie", "series"],
  resources: ["stream"],
  idPrefixes: ["tt"]
};

// 1. Manifest Endpoint
app.get('/manifest.json', (req, res) => {
  res.json(MANIFEST);
});

// Manifest with user-supplied debrid configuration
app.get('/:configuration/manifest.json', (req, res) => {
  res.json(MANIFEST);
});

// 2. Stream Resolver Endpoint
app.get('/stream/:type/:id.json', async (req, res) => {
  await handleStream(req.params.type, req.params.id, null, res);
});

app.get('/:configuration/stream/:type/:id.json', async (req, res) => {
  await handleStream(req.params.type, req.params.id, req.params.configuration, res);
});

async function handleStream(type, id, configuration, res) {
  try {
    let streams = [];
    const targetUrl = `https://torrentio.strem.fun/${configuration ? configuration + '/' : ''}stream/${type}/${id}.json`;
    
    const response = await axios.get(targetUrl, {
      timeout: 5000,
      headers: { 'User-Agent': 'Somnius/1.0.0 (macOS)' }
    });

    if (response.data && response.data.streams) {
      streams = response.data.streams.map(s => ({
        ...s,
        name: `[Somnius] ${s.name || 'HD Stream'}`
      }));
    }

    res.json({ streams });
  } catch (err) {
    console.error('Error fetching streams:', err.message);
    res.json({ streams: [] });
  }
}

const PORT = process.env.PORT || 7000;
app.listen(PORT, () => {
  console.log(`Somnius Addon Server listening on port ${PORT}`);
});
