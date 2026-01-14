const admin = require('firebase-admin');
const fs = require('fs');

// 1. Path to your credentials (the "VIP Pass")
const serviceAccount = require("./latest11Jan2026.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 2. Read the backup file you created earlier
const data = JSON.parse(fs.readFileSync('backup.json', 'utf8'));

async function restoreData() {
  console.log('🚀 Starting Restore Process...');
  
  for (const collectionName in data) {
    console.log(`Restoring collection: ${collectionName}...`);
    const collectionData = data[collectionName];

    for (const docId in collectionData) {
      // This line pushes the data to Firestore
      await db.collection(collectionName).doc(docId).set(collectionData[docId]);
    }
  }
  
  console.log('✅ Restore Complete! Your database has been synchronized.');
  process.exit();
}

restoreData().catch(err => {
  console.error('❌ Error during restore:', err);
  process.exit(1);
});