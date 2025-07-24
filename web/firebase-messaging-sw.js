importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-messaging-compat.js');

// Initialize Firebase in the service worker using the same config as the app.
firebase.initializeApp({
  apiKey: "AIzaSyDX_fhBTQmwm-KP8Qu2gfwFQylGuaEm4VA",
  authDomain: "eng-system.firebaseapp.com",
  projectId: "eng-system",
  storageBucket: "eng-system.firebasestorage.app",
  messagingSenderId: "526461382833",
  appId: "1:526461382833:web:46090faa13de2d4b30f290",
  measurementId: "G-NMMTY5PN4Y"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  if (!title) return;
  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png'
  });
});
