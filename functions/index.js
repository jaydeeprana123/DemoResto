const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.updateStaffPassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in.",
    );
  }

  const staffUid = data.staffUid;
  const newPassword = data.newPassword;

  if (!staffUid || typeof staffUid !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Staff id is required.",
    );
  }

  if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters.",
    );
  }

  const db = admin.firestore();
  const callerRef = db.collection("users").doc(context.auth.uid);
  const staffRef = db.collection("users").doc(staffUid);

  const [callerSnap, staffSnap] = await Promise.all([
    callerRef.get(),
    staffRef.get(),
  ]);

  if (!callerSnap.exists) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Caller profile not found.",
    );
  }

  const caller = callerSnap.data();
  if (caller.role !== "Admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only restaurant admins can change staff passwords.",
    );
  }

  if (!staffSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Staff account not found.");
  }

  const staff = staffSnap.data();
  if (staff.role !== "Staff") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Target user is not a staff account.",
    );
  }

  if (staff.restaurantId !== caller.restaurantId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Staff does not belong to your restaurant.",
    );
  }

  await admin.auth().updateUser(staffUid, { password: newPassword });
  return { success: true };
});

exports.deleteStaff = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in.",
    );
  }

  const staffUid = data.staffUid;

  if (!staffUid || typeof staffUid !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Staff id is required.",
    );
  }

  if (staffUid === context.auth.uid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "You cannot delete your own account here.",
    );
  }

  const db = admin.firestore();
  const callerRef = db.collection("users").doc(context.auth.uid);
  const staffRef = db.collection("users").doc(staffUid);

  const [callerSnap, staffSnap] = await Promise.all([
    callerRef.get(),
    staffRef.get(),
  ]);

  if (!callerSnap.exists) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Caller profile not found.",
    );
  }

  const caller = callerSnap.data();
  if (caller.role !== "Admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only restaurant admins can delete staff.",
    );
  }

  if (!staffSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Staff account not found.");
  }

  const staff = staffSnap.data();
  if (staff.role !== "Staff") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Target user is not a staff account.",
    );
  }

  if (staff.restaurantId !== caller.restaurantId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Staff does not belong to your restaurant.",
    );
  }

  await admin.auth().deleteUser(staffUid);
  await staffRef.delete();
  return { success: true };
});

async function loadImageKitConfig(db, restaurantId) {
  const restSnap = await db.collection("restaurants").doc(restaurantId).get();
  const restData = restSnap.data() || {};

  let publicKey = restData.imagekitPublicKey;
  let privateKey = restData.imagekitPrivateKey;
  let urlEndpoint = restData.imagekitUrlEndpoint;

  if (!publicKey || !privateKey || !urlEndpoint) {
    const settingsSnap = await db
      .collection("restaurants")
      .doc(restaurantId)
      .collection("settings")
      .doc("imagekit")
      .get();
    if (settingsSnap.exists) {
      const settings = settingsSnap.data() || {};
      publicKey = publicKey || settings.publicKey;
      privateKey = privateKey || settings.privateKey;
      urlEndpoint = urlEndpoint || settings.urlEndpoint;
    }
  }

  return { publicKey, privateKey, urlEndpoint };
}

exports.uploadZomatoScreenshot = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in.",
    );
  }

  const fileName = data.fileName;
  const fileBase64 = data.fileBase64;
  const folder = data.folder || "/zomato-orders";

  if (!fileName || typeof fileName !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "fileName is required.",
    );
  }

  if (!fileBase64 || typeof fileBase64 !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "fileBase64 is required.",
    );
  }

  const db = admin.firestore();
  const callerRef = db.collection("users").doc(context.auth.uid);
  const callerSnap = await callerRef.get();

  if (!callerSnap.exists) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Caller profile not found.",
    );
  }

  const caller = callerSnap.data();
  const restaurantId = caller.restaurantId;

  if (!restaurantId || typeof restaurantId !== "string") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "No restaurant linked to your account.",
    );
  }

  const { publicKey, privateKey, urlEndpoint } = await loadImageKitConfig(
    db,
    restaurantId,
  );

  if (!publicKey || !privateKey || !urlEndpoint) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "ImageKit is not configured. Open Settings → Zomato / ImageKit, enter all three fields, and tap Save.",
    );
  }

  const buffer = Buffer.from(fileBase64, "base64");
  const auth = Buffer.from(`${privateKey}:`).toString("base64");
  const subtype = fileName.toLowerCase().endsWith(".png")
    ? "png"
    : fileName.toLowerCase().endsWith(".webp")
      ? "webp"
      : "jpeg";

  const form = new FormData();
  form.append("file", new Blob([buffer], { type: `image/${subtype}` }), fileName);
  form.append("fileName", fileName);
  form.append("folder", folder);
  form.append("publicKey", publicKey);
  form.append("useUniqueFileName", "true");

  const response = await fetch("https://upload.imagekit.io/api/v1/files/upload", {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
    },
    body: form,
  });

  const body = await response.text();
  if (!response.ok) {
    throw new functions.https.HttpsError(
      "internal",
      `ImageKit upload failed (${response.status}): ${body}`,
    );
  }

  let decoded;
  try {
    decoded = JSON.parse(body);
  } catch (error) {
    throw new functions.https.HttpsError(
      "internal",
      "ImageKit upload returned an invalid response.",
    );
  }

  const url = decoded.url;
  if (!url || typeof url !== "string") {
    throw new functions.https.HttpsError(
      "internal",
      "ImageKit upload did not return a URL.",
    );
  }

  return { url };
});
