# 🎨 Animated Frontend Setup

## Step 1: Create React App
```cmd
cd "c:\Users\Administrator\Desktop\serverless media factory"
npx create-react-app frontend
cd frontend
npm install axios
```

## Step 2: Replace Files

Copy these files:
- `frontend-app.js` → `frontend/src/App.js`
- `frontend-app.css` → `frontend/src/App.css`

## Step 3: Configure API Endpoints

After running `terraform apply`, get the outputs:
```cmd
terraform output
```

Then edit `frontend/src/App.js` and replace:
- `YOUR_API_ENDPOINT` with the api_endpoint output
- `YOUR_CLOUDFRONT_URL` with the cloudfront_url output

## Step 4: Run Development Server
```cmd
npm start
```

Opens at http://localhost:3000

## Features

✨ **Animations:**
- Animated starfield background
- Floating logo
- Smooth card transitions
- Progress bar with shimmer effect
- Bounce and pulse effects

🎨 **Design:**
- Glassmorphism cards
- Gradient backgrounds
- Modern purple theme
- Responsive layout
- Hover effects

📱 **Mobile Responsive:**
- Adapts to all screen sizes
- Touch-friendly buttons
- Optimized layouts

## Deploy to Production

```cmd
npm run build
aws s3 sync build/ s3://YOUR_OUTPUT_BUCKET/frontend/ --delete
```

Access via CloudFront URL!
