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

## Mobile App (Flutter)
- [x] Disable foreground FCM notification for `new_order` to prevent duplicate alerts
- [x] Add notification routing to `OrdersScreen` on tap
- [x] Add "Payment Due" banner for non-Lifetime plans
- [x] Fix Flutter App notification issues:
    - [x] Add `navigatorKey` to `main.dart`
    - [x] Implement tap-to-navigate in `notification_service.dart`
    - [x] Suppress duplicate notifications in `notification_service.dart`
    - [x] Add "Payment Due" notification check in `overview_screen.dart`

## General / Service Worker
- [ ] Ensure Service Worker notification click routes correctly
- [ ] Link payment plan (Razorpay integration link)
- [/] Bulk generate AI images for Yaarana Cafe
- [x] Delete irrelevant files and clean up repository
- [ ] Push all changes to GitHub
