# Tasks

## Web App: `public/index.html`
- [x] Hide 'Sign in' & 'Get started' on mobile in header
- [x] Add smooth CSS transition for navigation/sliding
- [x] Adjust padding/spacing for a more premium aesthetic

## Web App: `public/menu.html`
- [x] Implement sticky search bar and shrinking header on scroll
- [x] Fix 'null' emoji in toast (`addItem` function)
- [x] Fix 'Order More Items' button (replace `location.reload()` with UI reset)
- [x] Fix realtime status updates not reflecting
- [x] Fix "Order More Items" bug and sticky search in `menu.html`

## Web App: `public/login.html`
- [x] Add Registration card layout
- [x] Implement smooth CSS flip/slide between Login and Register
- [x] Implement Dashboard registration logic (`dashboard.html`)

## Web App: `public/customer.html`
- [x] Show total bill when status is "completed" or "Send bill"
- [x] Add "Politly ask for feedback" UI component beneath the bill summary
- [x] Enhance Customer bill summary and feedback request (`customer.html`)
- [x] Improve Feedback page aesthetics (`feedback.html`)
- [x] Implement 20s auto-refresh fallback for live tracking

## Mobile App (Flutter)
- [x] Implement smart real-time updates (update local list on `UPDATE`)
- [x] Add 30s periodic refresh fallback in `OrdersScreen`
- [x] Add `ValueKey` to order cards for UI stability
- [x] Implement notification deduplication (prevent Realtime vs FCM overlap)
- [x] Fix missing stream subscription variables in `AuthGate.dart`
- [x] Standardize Supabase client access across the app

## Owner Dashboard (Web)
- [x] Implement 30s background sync for orders/overview
- [x] Consolidate real-time listeners for orders and waiter calls

## General / Infrastructure
- [x] Deduplicate FCM tokens in `send-order-notification` Edge Function
- [x] Fix status update triggers causing multiple customer notifications
- [x] Push all changes to GitHub
- [x] Generate production APK for distribution
