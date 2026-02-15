# Ima

A macOS task manager centered on decay and impermanence, not long-term planning.

## Philosophy

Ima is designed around the concept that not everything needs to be preserved forever. Tasks have fixed expiration times, and when they expire, they disappear permanently—no archives, no recovery, no second chances.

## Core Features

### Task Management
- **Fixed Expiration**: Every task has a maximum duration (capped at 7 days by default)
- **Permanent Deletion**: Expired tasks disappear forever
- **Urgency-Based Display**: Tasks are sorted by time remaining
- **Dominant Task View**: The most urgent task gets prominent visual treatment

### Visual Design
- **Liquid Glass Aesthetic**: Modern, translucent UI elements with subtle gradients
- **Fire Indicator**: A dynamic flame visualization that reflects your completion habits
- **Urgency Colors**: Visual cues that intensify as deadlines approach
- **Dark Mode Optimized**: Designed to look best in dark mode

### Menu Bar Integration
- **Quick Status**: See active task count and next expiration
- **Fast Access**: Add tasks and open the app from the menu bar
- **Keyboard Shortcuts**: Quick actions with standard macOS shortcuts

## Usage

### Creating Tasks
1. Click the "+" button or use ⌘N
2. Enter a task title (required)
3. Choose duration from presets (1h, 6h, 1d, 3d) or set custom
4. Optionally add location and link
5. Tasks are intentionally limited to prevent over-planning

### Task Display
- **Dominant Card**: Next expiring task shown prominently
- **Secondary Cards**: Other tasks in smaller cards below
- **Time Remaining**: Live countdown with urgency color coding
- **Completion**: Click the circle to mark complete

### Fire Indicator
The floating fire bar at the bottom shows your task completion patterns:
- **Bright**: High completion rate before expiry
- **Dim**: Many tasks expiring incomplete
- **Organic**: Changes slowly, never resets instantly

## Settings

Access via menu bar → Preferences or ⌘,

- **Maximum Duration**: Set the cap for task durations (up to 7 days)
- **Fire Intensity**: Adjust visual intensity of the fire indicator
- **Subtle Stats**: Toggle display of completion statistics

## Design Principles

- **No Reminders**: Tasks don't nag you
- **No Streaks**: No gamification or progress tracking
- **No Archives**: Expired tasks are gone forever
- **No Future Planning**: Focus on immediate, actionable items
- **Intentional Friction**: Creating tasks requires deliberate action

## Technical Details

- Built with SwiftUI for macOS 15.5+
- Liquid glass effects using modern macOS materials
- Persistent storage with UserDefaults
- Menu bar integration with system tray
- Real-time countdown updates

## Philosophy in Practice

Ima encourages you to:
- Focus on what's immediately actionable
- Accept that some things will expire
- Develop better judgment about what truly matters
- Experience time as finite and irreversible

The app rewards finishing tasks before they expire and quietly punishes neglect through the dimming fire indicator—a non-verbal signal of your relationship with time and commitment.
