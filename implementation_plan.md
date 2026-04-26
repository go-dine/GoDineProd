# Implementation Plan: GoDine UI/UX & Notifications Refinement

Based on your feedback, here is the technical plan to fix the UI glitches, enhance the aesthetic premium feel, and resolve the notification/status bugs across both the customer web app and the owner flutter app.

## User Review Required
Please review the proposed solutions for the double notification issue and the "Send Bill" flow. 

## Open Questions
1. **Notifications**: The Flutter app receives notifications from two sources simultaneously when open: Supabase Realtime (which instantly plays a sound and updates UI) and Firebase Cloud Messaging (FCM) (which shows a foreground notification banner). To fix the "2 notifications" bug, my plan is to disable the foreground FCM banner for new orders, relying instead on the Realtime local notification which is faster. Is this approach acceptable?
2. **Order More Items**: Should clicking "Order More Items" simply close the success overlay without reloading the page, or do you want it to navigate to a specific category? I plan to simply close the overlay and reset the cart to keep it seamless.

## Proposed Changes

### Web Application (Customer UI & Landing Pages)

#### [MODIFY] `public/index.html`
- **Mobile Navigation Fix**: Hide the "Sign in" and "Get started free" buttons on mobile view (`max-width: 640px`) inside the `.nav-right` container, as they overlap the hamburger menu. They are already accessible inside the `#mobile-menu`.
- **Aesthetics**: Adjust section padding and margin to conserve space and increase the premium feel (e.g., reduce the massive `120px` padding on mobile).
- **Page Transitions**: Add CSS rules for smooth sliding/fade transitions (`transform: translateX()`, `opacity: 0 -> 1`) when navigating between pages.

#### [MODIFY] `public/menu.html`
- **Sticky Header & Scroll Shrink**: Add a javascript `scroll` listener. When the user scrolls down, the large `.rest-info` header (restaurant name, table info) will collapse (`height: 0`, `opacity: 0`), and the `.search-wrap` will become a sticky header at the top of the viewport.
- **Null Emoji Fix**: Update the `showToast` logic in `addItem` to verify if `dish.emoji` is actually the string `"null"`. (e.g., `const emoji = (dish.emoji && dish.emoji !== "null") ? dish.emoji : "🍽️";`).
- **"Order More Items" Bug**: Replace `onclick="location.reload()"` with a custom Javascript function that closes the `#success-screen` overlay, clears the cart, and resets the UI state smoothly without a hard refresh.
- **Realtime Status Fix**: Verify and fix the Supabase channel subscription for `godine_active_order_id` so the status tracker updates live (Placed → Preparing → Ready).
- **Feedback UI**: Improve the feedback section UI inside the order success screen.

#### [MODIFY] `public/customer.html`
- **Send Bill & Feedback Flow**: When an order status is marked as "completed" or "Send bill", automatically display the total bill summary. Immediately below the bill summary, inject the improved "Politely ask for feedback" component.

#### [MODIFY] `public/login.html`
- **Registration Flow**: Add a "Register" tab alongside the Login form. Use a smooth CSS transform slide/card-flip animation to switch between "Login" and "Register" forms.

#### [MODIFY] `public/sw.js` (Service Worker)
- **Notification Click Redirection**: Ensure the `notificationclick` event properly opens the correct order tracking URL (`/customer.html` for customers, or focus the dashboard for owners).

---

### Flutter App (Owner Application)

#### [MODIFY] `godine-owner-app/lib/services/notification_service.dart`
- **Double Notification Fix**: In `setupForegroundHandler()`, add a check: if the app is in the foreground, do not show the FCM notification banner for `new_order` events (because the `orders_screen.dart` realtime subscription already triggers a local alert for it). This prevents the duplicate ping.
- **Notification Redirection**: Integrate `flutter_local_notifications` `onDidReceiveNotificationResponse` to redirect the user directly to the `OrdersScreen` when they tap a notification.

#### [MODIFY] `godine-owner-app/lib/screens/dashboard_screen.dart` (or `main.dart`)
- **Payment Due Notification**: Add a check against the owner's `subscription_plan`. If it is not `Lifetime` and the subscription is nearing expiry or expired, inject a visual "Payment Due" notification banner at the top of the dashboard.
- **Link Payment Plan**: Ensure the banner contains a "Pay Now" button that routes to the web-based Razorpay link for their selected plan.

## Verification Plan
### Automated Tests
- Test the `.rest-info` shrinking and sticky search bar on scroll in `menu.html`.
- Trigger a mock order and verify `showToast` displays "🍽️ Garlic Bread added" instead of "null".

### Manual Verification
- Test mobile view of `index.html` to ensure no overlap.
- Emulate "Order More Items" click and ensure the overlay disappears correctly.
- Test the new login/registration sliding card on `login.html`.
- (For Owner App) Generate an order and verify only 1 notification appears on the Flutter device.
- Verify the feedback form renders cleanly when an order reaches the "bill sent" status.
