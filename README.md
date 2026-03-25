# GoDine — Multi-Restaurant Smart Dining Platform

> **Scan. Order. Enjoy.** — A multi-tenant platform for restaurant owners to manage menus, and for customers to order seamlessly via QR codes.

GoDine allows any restaurant owner to register, set up their digital menu, and generate table-specific QR codes. Customers simply scan the QR code to view the menu and place detailed orders, which appear instantly on the restaurant's live kitchen dashboard.

## 🌟 Features
- **Multi-Tenant Architecture**: Multiple restaurants can use the same deployment, separated by unique URL slugs (e.g., `?r=my-restaurant`).
- **Owner Dashboard**: Registration, secure login, menu management (add/edit/delete dishes), and live order tracking.
- **QR Code Generation**: Automatically generate and download table-specific QR codes.
- **Mobile-First Customer Menu**: Beautiful, intuitive menu interface designed for phones.
- **Real-time Order Status**: Customers can track their order status, and kitchen staff can manage it from `Pending` -> `Preparing` -> `Ready` -> `Completed`.

---

## 🚀 Quick Start (Local Development)

To run the application locally:
1. Clone the repository.
2. Open the project folder in VS Code.
3. Start a local server (e.g., using the "Live Server" extension).
4. Navigate to `index.html` (Homepage) or `dashboard.html` (Owner Portal).

---

## ⚙️ Production Setup & Configuration

This platform uses **Supabase** for its backend database. Follow these steps to configure the project for production.

### Step 1: Create a Supabase Project
1. Go to [supabase.com](https://supabase.com) and create a New Project.
2. Wait for the database to finish provisioning.

### Step 2: Database Schema & Seed Data
1. In your Supabase dashboard, go to the **SQL Editor** and click **New Query**.
2. Open the `setup.sql` file in your repository, copy its contents, and paste it into the query editor.
3. Click **Run** to create the `restaurants`, `dishes`, and `orders` tables.
   *(Note: The query also seeds a demo restaurant with login slug `demo` and password `demo1234`)*.

### Step 3: Configure Database Security (Crucial for Production)
The default `setup.sql` disables Row Level Security (RLS) for easy development. **For production, you must enable RLS** to prevent unauthorized access.
1. In Supabase, go to **Authentication** -> **Policies** (or the SQL Editor).
2. Run the following to enable RLS:
```sql
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
```
3. Create policies to ensure:
   - Anyone can `SELECT` from `restaurants` and `dishes` (to view menus).
   - Anyone can `INSERT` into `orders` (to place orders).
   - Only authenticated restaurant owners can `UPDATE`/`DELETE` their own dishes and view/update their own orders.

### Step 4: Link Frontend to Supabase
1. In Supabase, go to **Project Settings** -> **API**.
2. Copy the **Project URL** and the **anon** public key.
3. Open `config.js` in your project folder and replace the placeholder values (or environment variables in production):
```javascript
const CONFIG = {
  supabaseUrl: 'YOUR_SUPABASE_PROJECT_URL',
  supabaseKey: 'YOUR_SUPABASE_ANON_KEY',
};
```

---

## 🌍 Deployment

Since GoDine is a purely static frontend application (HTML/CSS/JS) communicating directly with Supabase, it can be hosted on any static hosting provider.

### Option A: Vercel (Recommended)
1. Push your code to a GitHub repository.
2. Go to [vercel.com](https://vercel.com) and log in.
3. Click **Add New Project**, import your GitHub repository, and click **Deploy**.

### Option B: Netlify
1. Push your code to GitHub.
2. Go to [netlify.com](https://netlify.com) -> **Add new site** -> **Import an existing project**.
3. Connect your repository and click **Deploy site**.

### Option C: GitHub Pages
1. Push your repository to GitHub.
2. Go to repository **Settings** -> **Pages**.
3. Set the source branch to `main` (or `master`) and save.

---

## 🍽️ Usage Guide for Restaurant Owners

1. **Register/Login**: Navigate to `/dashboard.html`. Click "Register here" to create a new restaurant account. You will need a unique slug and a password.
2. **Menu Management**: Once logged in, go to the **Menu** tab. Add your dishes, including descriptions, prices, categories, and emojis.
3. **Print QR Codes**: Go to the **QR Codes** tab. You'll see a preview of QR codes for all your tables. Print these and place them on the physical tables.
4. **Live Orders**: Keep the **Orders** tab open in your kitchen or front desk. As customers scan the QR codes and place orders, they will appear here instantly. Update the status as you prepare the food!

## URL Structure Reference
| Page | Path / URL Format | Description |
|---|---|---|
| **Marketing Home** | `/index.html` | The landing page |
| **Owner Dashboard** | `/dashboard.html` | Restaurant management portal |
| **Customer Menu** | `/menu.html?r=slug&table=3` | The menu accessed via QR code |
