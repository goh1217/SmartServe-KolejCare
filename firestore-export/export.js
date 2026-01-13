const admin = require("firebase-admin");
const fs = require("fs");
const { Parser } = require("json2csv");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportFilteredData() {
  try {
    // 1️⃣ Define naming variables at the start of the function
    const now = new Date();
    const monthName = now.toLocaleString('default', { month: 'long' }); // e.g., "January"
    const year = now.getFullYear();
    const fileName = `complaints_${monthName}_${year}`;

    // ✅ Date range for filtering
    const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

    console.log(`Searching for: ${monthName} ${year}...`);

    const snapshot = await db
      .collection("complaint")
      .where("reportStatus", "==", "Completed")
      .where("reportedDate", ">=", firstDay)
      .where("reportedDate", "<=", lastDay)
      .get();

    if (snapshot.empty) {
      console.log("No matching documents found.");
      return;
    }

    const data = snapshot.docs
      .map(doc => {
        const docData = doc.data();
        if (docData.damagePic && docData.damagePic.length > 0) {
          return {
            damagePic: docData.damagePic,
            reportedDate: docData.reportedDate.toDate ? docData.reportedDate.toDate() : docData.reportedDate,
            urgencyLevel: docData.urgencyLevel,
            urgencyLevelAI: docData.urgencyLevelAI
          };
        }
        return null;
      })
      .filter(doc => doc !== null);

    if (data.length === 0) {
      console.log("No documents with non-empty damagePic found.");
      return;
    }

    // 2️⃣ Save files using the fileName defined at the top
    fs.writeFileSync(`./${fileName}.json`, JSON.stringify(data, null, 2));
    console.log(`✅ JSON export complete: ${fileName}.json`);

    const parser = new Parser();
    const csv = parser.parse(data);
    fs.writeFileSync(`./${fileName}.csv`, csv);
    console.log(`✅ CSV export complete: ${fileName}.csv`);

  } catch (error) {
    console.error("❌ Error exporting data:", error);
  }
}

exportFilteredData();
