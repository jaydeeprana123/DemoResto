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
