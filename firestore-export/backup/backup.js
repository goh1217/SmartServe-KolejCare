const admin = require('firebase-admin');
const fs = require('fs');

// Path to your credentials file
const serviceAccount = require("./latest11Jan2026.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportData() {
  const collections = await db.listCollections();
  const output = {};

  for (const collection of collections) {
    console.log(`Exporting: ${collection.id}...`);
    const snapshot = await collection.get();
    output[collection.id] = {};
    
    snapshot.forEach(doc => {
      output[collection.id][doc.id] = doc.data();
    });
  }

  fs.writeFileSync('backup.json', JSON.stringify(output, null, 2));
  console.log('✅ Success! Your data is saved in backup.json');
  process.exit();
}

exportData().catch(console.error);