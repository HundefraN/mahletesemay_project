#!/bin/bash
if [ -d "flutter" ]; then
  cd flutter && git pull && cd ..
else
  git clone https://github.com/flutter/flutter.git -b stable
fi
export PATH="$PATH:`pwd`/flutter/bin"
flutter build web --release --dart-define=SUPABASE_URL=https://onsvnudakxkrqazrufar.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uc3ZudWRha3hrcnFhenJ1ZmFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwNzYzNzQsImV4cCI6MjEwMjY1MjM3NH0.1U-gR05Ojn0FiHcmK8J4TOyloFw7dbHrQ0Y31bA8os4
