// Firebase Cloud Messaging Web Service Worker
// Automatically registered by Firebase Messaging for background web push notifications.

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyMockKeyForCarelyDevelopmentEnvironment",
  authDomain: "carely-dev.firebaseapp.com",
  projectId: "carely-dev",
  storageBucket: "carely-dev.appspot.com",
  messagingSenderId: "100000000001",
  appId: "1:100000000001:web:mock1234567890abcdef"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background push received:', payload);
  const notificationTitle = payload.notification?.title || payload.data?.title || 'Carely';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {}
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
