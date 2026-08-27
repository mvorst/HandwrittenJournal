# TraceRight - Handwriting Practice App for iPad

## Design Document v1.0

---

## 1. Overview

**TraceRight** is an iPad app that helps 1st-3rd graders (ages 6-9) improve their
handwriting through guided tracing with Apple Pencil. Children dictate sentences using
voice input, then trace over the rendered text. Real-time visual feedback shows green
ink inside letter boundaries and red ink outside, teaching precision and letter formation.
The app is gamified with a level progression system that gradually reduces font size and
weight as the child improves.

**Platform:** iPad only (Apple Pencil required)
**Target OS:** iOS 17+
**Bundle ID:** `ai.thebridgeto.education.handwriting`
**Framework:** SwiftUI + PencilKit + Speech framework

---

## 2. User Flow

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐     ┌────────────────┐     ┌───────────────┐
│  Welcome     │────▶│  Home Screen │────▶│  Dictation   │────▶│  Tracing       │────▶│  Results       │
│  (First run) │     │  (Dashboard) │     │  Screen      │     │  Screen        │     │  Screen        │
└─────────────┘     └─────────────┘     └──────────────┘     └────────────────┘     └───────────────┘
                           │                                         │                       │
                           │                                         ▼                       │
                           │                                  ┌────────────┐                 │
                           │                                  │  Reveal     │                 │
                           │                                  │  (User ink  │                 │
                           │                                  │   only)     │                 │
                           │                                  └────────────┘                 │
                           │                                                                 │
                           ◀─────────────────────────────────────────────────────────────────┘
```

### 2.1 Welcome Screen (First Launch Only)

On first launch, the app presents a Welcome Screen to collect the child's first name.
This name is used throughout the app for personalized greetings, encouragement, and
feedback.

- Displays a friendly welcome message: "Welcome to TraceRight!"
- A large text field with the prompt: "What's your first name?"
- The field uses the level-1 guide font (large, bold) so the child can see their name
  rendered in the same style they will be tracing
- A "Let's Go!" button appears once at least 1 character is entered
- The name is saved to `PlayerProgress` and persists across sessions
- After the name is entered, the app navigates directly to the Dashboard
- On all subsequent launches, the Welcome Screen is skipped and the Dashboard loads
  immediately
- The name can be changed later in Settings

### 2.2 Home Screen (Dashboard)

The landing screen shows:

- **Personalized greeting** at the top: "Hi, {name}!" (e.g., "Hi, Emma!")
- **Current level** indicator with a progress bar to the next level
- **Daily streak** counter (flame icon with day count)
- **Total points** display
- **"Start Writing" button** - large, centered, primary action
- **Badge showcase** - horizontal scroll of earned badges (greyed-out for unearned)
- **Settings gear** - top-right corner

The UI uses large, friendly typography and bright colors appropriate for the age group.
No complex navigation; one primary call to action.

### 2.3 Dictation Screen

- Displays a large microphone button in the center
- Prompt text: "What do you want to write, {name}?" (e.g., "What do you want to write, Emma?")
- Tap microphone to begin recording; the button animates with a pulsing ring
- Uses Apple's `SFSpeechRecognizer` for on-device speech-to-text
- Displays the transcribed text in real time below the microphone
- **"Done" button** appears once speech is detected
- **"Try Again" button** clears text and restarts recognition
- **Manual text entry** - small keyboard icon in the corner for cases where dictation
  is impractical (noisy environment, parent wants to type a specific sentence)
- Transcribed text is passed to the Tracing Screen

**Constraints:**
- Maximum text length: 200 characters (enforced with a gentle message)
- Minimum text length: 1 character

### 2.4 Tracing Screen

This is the core experience. It has two phases: **Tracing Phase** and **Reveal Phase**.

#### 2.3.1 Layout

```
┌──────────────────────────────────────────────────────┐
│  Level 3          ★ ★ ★              [Done] [Clear]  │
├──────────────────────────────────────────────────────┤
│                                                      │
│   H e l l o   w o r l d              (guide text)    │
│                                                      │
│   (child traces with Apple Pencil on top of text)    │
│                                                      │
│   T h i s   i s   f u n             (line 2 if any)  │
│                                                      │
│                                                      │
├──────────────────────────────────────────────────────┤
│  Progress: ████████░░░░ 67%    Points: +45           │
└──────────────────────────────────────────────────────┘
```

- The dictated text is rendered as the **guide layer** in black
- Text is laid out using lined baselines (like notebook paper) with faint horizontal
  rules to reinforce proper letter placement
- Multi-line text wraps naturally at word boundaries
- The child draws on a transparent **ink layer** directly on top of the guide text

#### 2.3.2 Real-Time Ink Coloring

This is the key technical feature. As the child draws with Apple Pencil:

1. Each new stroke segment is tested against the **letter mask** (see Section 4)
2. Pixels/segments that fall **inside** letter boundaries render as **green**
3. Pixels/segments that fall **outside** letter boundaries render as **red**
4. The coloring is applied per-stroke-point in near real-time

The child sees immediate feedback: green = good, red = went outside the letter.

#### 2.3.3 Controls

- **Done button** - ends the tracing phase, triggers scoring and the reveal animation
- **Clear button** - erases all ink, allows the child to retry (does not count as a
  new attempt)
- **Undo button** - removes the last stroke

#### 2.3.4 Reveal Phase

When the child taps "Done":

1. A short animation fades out the black guide text (0.5s fade)
2. Only the child's colored ink remains on screen
3. The child sees their actual handwriting with green (accurate) and red (inaccurate)
   portions visible
4. A "See My Score" button appears, leading to the Results Screen

### 2.5 Results Screen

Displays the child's performance:

- **Star rating** (1-3 stars) based on accuracy percentage
  - 1 star: 50-69% accuracy
  - 2 stars: 70-89% accuracy
  - 3 stars: 90-100% accuracy
  - Below 50%: encouraging message, no stars, but still earn some points
- **Accuracy percentage** shown as a filled circle/ring animation
- **Points earned** for this attempt (see Section 5.2)
- **New badge notification** if a badge was earned (with a celebratory animation)
- **Streak update** if this is the first completion of the day
- **Buttons:**
  - "Try Again" - return to Tracing Screen with same text
  - "New Sentence" - return to Dictation Screen
  - "Home" - return to Dashboard

---

## 3. Level Progression System

### 3.1 Level Definitions

The game has 10 levels. Each level adjusts font size and weight:

| Level | Font Size (pt) | Font Weight     | Line Spacing | Description          |
|-------|-----------------|-----------------|--------------|----------------------|
| 1     | 96              | Black (W900)    | 120pt        | Extra large, boldest |
| 2     | 84              | Heavy (W800)    | 108pt        | Very large, heavy    |
| 3     | 72              | Bold (W700)     | 96pt         | Large, bold          |
| 4     | 64              | Semibold (W600) | 84pt         | Large, semibold      |
| 5     | 56              | Medium (W500)   | 72pt         | Medium-large         |
| 6     | 48              | Regular (W400)  | 64pt         | Medium               |
| 7     | 42              | Regular (W400)  | 56pt         | Medium-small         |
| 8     | 36              | Light (W300)    | 48pt         | Small, light         |
| 9     | 30              | Light (W300)    | 40pt         | Small, lighter       |
| 10    | 24              | Thin (W200)     | 32pt         | Smallest, thinnest   |

### 3.2 Font Choice

The guide text uses a handwriting-style educational font. Recommended options:

1. **Primary:** A custom bundled font based on D'Nealian or Zaner-Bloser handwriting
   styles commonly taught in US elementary schools
2. **Fallback:** `SF Pro Rounded` - Apple's system font with rounded terminals, which
   is friendly and legible at all weights

The font must support all weights from Thin to Black. If a custom educational font is
used, all 8+ weight variants must be included in the bundle.

### 3.3 Level Advancement

- Each level requires earning a cumulative number of stars to unlock:

| Level | Cumulative Stars Required |
|-------|---------------------------|
| 1     | 0 (starting level)        |
| 2     | 6                         |
| 3     | 15                        |
| 4     | 27                        |
| 5     | 42                        |
| 6     | 60                        |
| 7     | 82                        |
| 8     | 108                       |
| 9     | 138                       |
| 10    | 172                       |

- Stars are earned across all attempts and accumulate permanently
- Leveling up triggers a celebratory full-screen animation (confetti + level badge)

---

## 4. Technical Architecture

### 4.1 Letter Mask Generation

The core technical challenge is determining whether Apple Pencil strokes fall inside
or outside the guide letters. The approach:

1. **Render guide text to a bitmap mask:**
   - Use `CoreText` (or `NSAttributedString` drawn into a `CGContext`) to render the
     guide text at the current level's font size and weight into an offscreen bitmap
   - Produce a binary alpha mask: pixels where the text was drawn = 1 (inside),
     all other pixels = 0 (outside)
   - Store this as a `CGImage` or raw pixel buffer for fast per-pixel lookup

2. **On each Apple Pencil input point:**
   - Map the touch coordinate to the corresponding pixel in the mask bitmap
   - Sample the mask at that pixel location
   - If mask value = 1 (inside letter): color the stroke segment green
   - If mask value = 0 (outside letter): color the stroke segment red

3. **Performance considerations:**
   - The mask is generated once when the Tracing Screen loads
   - Pixel lookups are O(1) and can be done at 120Hz without frame drops
   - Use `PKCanvasView` from PencilKit for the drawing surface, but intercept
     stroke data for custom rendering (see 4.2)

### 4.2 Custom Ink Rendering

PencilKit's `PKCanvasView` provides smooth Apple Pencil input with pressure, tilt,
and azimuth support. However, we need custom stroke coloring, which PencilKit does
not natively support on a per-segment basis.

**Approach: Hybrid rendering**

1. Use `PKCanvasView` in a transparent overlay to capture stroke input
2. Implement a custom `PKCanvasViewDelegate` to intercept each new stroke point
3. For each point, determine inside/outside status from the mask
4. Render the colored strokes in a separate custom `CALayer` or `MTKView` beneath
   the PencilKit canvas
5. Keep the PencilKit canvas ink transparent/invisible - it serves only as the input
   capture mechanism

**Alternative approach:** Skip PencilKit entirely and use raw `UITouch` handling with
`touchesBegan/Moved/Ended` or the `UIGestureRecognizer` API. This gives full control
over rendering but loses PencilKit's built-in palm rejection, stroke smoothing, and
pressure response. A custom Bezier-curve-based renderer would be needed.

**Recommended:** Use PencilKit for input capture and palm rejection, with a custom
Metal or Core Graphics render layer for the colored output. This hybrid approach gives
the best balance of input quality and rendering control.

### 4.3 Stroke Data Model

```swift
struct TracingPoint {
    let location: CGPoint      // Screen coordinate
    let timestamp: TimeInterval
    let force: CGFloat         // Apple Pencil pressure (0.0-1.0)
    let isInsideLetter: Bool   // Result of mask lookup
}

struct TracingStroke {
    let points: [TracingPoint]
    var insideRatio: CGFloat {
        let insideCount = points.filter { $0.isInsideLetter }.count
        return CGFloat(insideCount) / CGFloat(max(points.count, 1))
    }
}

struct TracingSession {
    let text: String
    let level: Int
    var strokes: [TracingStroke]
    var overallAccuracy: CGFloat {
        let allPoints = strokes.flatMap { $0.points }
        let insideCount = allPoints.filter { $0.isInsideLetter }.count
        return CGFloat(insideCount) / CGFloat(max(allPoints.count, 1))
    }
}
```

### 4.4 Screen Layout Engine

For multi-line text rendering:

1. Use `NSAttributedString` with the level's font size/weight to calculate text layout
   via `CTFramesetter`
2. Determine line breaks, line origins, and glyph positions
3. Render faint horizontal baselines (like ruled notebook paper) at each line's
   baseline y-coordinate
4. Optionally render a dashed midline for uppercase/lowercase letter height reference
5. The same layout parameters are used for both the visible guide text layer and the
   offscreen mask bitmap, ensuring pixel-perfect alignment

### 4.5 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                         │
│  ┌──────────┐  ┌──────────────┐  ┌──────────┐  ┌─────────┐ │
│  │Dashboard │  │ Dictation    │  │ Tracing   │  │ Results │ │
│  │View      │  │ View         │  │ View      │  │ View    │ │
│  └──────────┘  └──────────────┘  └──────────┘  └─────────┘ │
├─────────────────────────────────────────────────────────────┤
│                     View Models                              │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │GameState     │  │SpeechManager  │  │TracingEngine     │  │
│  │ViewModel     │  │               │  │                  │  │
│  └──────────────┘  └───────────────┘  └──────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      Core Services                           │
│  ┌────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │MaskRenderer│  │StrokeColorizer│ │ScoringEngine      │   │
│  │(CoreText + │  │(per-point     │ │(accuracy calc,    │   │
│  │ CGContext)  │  │ mask lookup)  │ │ stars, points)    │   │
│  └────────────┘  └──────────────┘  └───────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                     Persistence                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  UserDefaults / SwiftData                             │   │
│  │  (level, stars, points, streak, badges, settings)     │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Apple Frameworks                           │
│  PencilKit  ·  Speech  ·  CoreText  ·  CoreGraphics  ·     │
│  Metal (optional)  ·  AVFoundation (sound effects)          │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Gamification System

### 5.1 Stars

Each tracing attempt earns 0-3 stars:

| Accuracy      | Stars | Label                                  |
|---------------|-------|----------------------------------------|
| 90% - 100%    | 3     | "Perfect, {name}!"                     |
| 70% - 89%     | 2     | "Great job, {name}!"                   |
| 50% - 69%     | 1     | "Good try, {name}!"                    |
| Below 50%     | 0     | "Keep going, {name}!"                  |

All encouragement messages throughout the app use `{name}` personalization.

Stars accumulate permanently and drive level progression.

### 5.2 Points

Points are calculated per attempt:

```
Base points    = accuracy_percentage * 10     (e.g., 85% = 85 points)
Star bonus     = stars_earned * 25            (e.g., 2 stars = 50 points)
Streak bonus   = current_streak * 5           (e.g., 3-day streak = 15 points)
Level bonus    = current_level * 10           (e.g., level 4 = 40 points)

Total points   = base + star_bonus + streak_bonus + level_bonus
```

Example: 85% accuracy at level 4 with a 3-day streak:
`85 + 50 + 15 + 40 = 190 points`

### 5.3 Daily Streaks

- A streak day is counted when the child completes at least 1 tracing attempt
- The streak counter resets if a full calendar day is missed
- Streak milestones (3, 7, 14, 30, 60, 100 days) award special badges

### 5.4 Badges

Badges are achievement-based unlockables. Categories:

**Accuracy Badges:**
| Badge             | Requirement                           |
|-------------------|---------------------------------------|
| Sharp Shooter     | First 3-star rating                   |
| Bullseye          | Five 3-star ratings                   |
| Laser Focus       | Twenty 3-star ratings                 |
| Perfectionist     | 100% accuracy on any attempt          |

**Streak Badges:**
| Badge             | Requirement                           |
|-------------------|---------------------------------------|
| On Fire           | 3-day streak                          |
| Unstoppable       | 7-day streak                          |
| Dedicated         | 14-day streak                         |
| Monthly Master    | 30-day streak                         |

**Level Badges:**
| Badge             | Requirement                           |
|-------------------|---------------------------------------|
| Getting Started   | Reach level 2                         |
| Warming Up        | Reach level 4                         |
| Skilled Writer    | Reach level 6                         |
| Expert            | Reach level 8                         |
| Handwriting Hero  | Reach level 10                        |

**Volume Badges:**
| Badge             | Requirement                           |
|-------------------|---------------------------------------|
| First Words       | Complete 1 tracing                    |
| Sentence Builder  | Complete 25 tracings                  |
| Paragraph Pro     | Complete 100 tracings                 |
| Story Teller      | Complete 500 tracings                 |

Each badge has an icon (simple SF Symbol-based illustration) and a name. Badges appear
greyed-out on the dashboard until earned, then animate into full color on unlock.

### 5.5 Unlockable Rewards

Points can be spent on cosmetic unlocks:

- **Ink colors:** Additional colors beyond green/red for the reveal view
  (blue, purple, gold, rainbow)
- **Paper themes:** Different notebook paper backgrounds (graph paper, dotted grid,
  colored paper, space theme, ocean theme)
- **Sound packs:** Different sound effects for drawing and scoring
- **Celebration animations:** Different confetti styles for star/badge reveals

Pricing: 200-1000 points per unlock, scaling with desirability.

---

## 6. Scoring Algorithm (Detail)

### 6.1 Accuracy Calculation

The primary metric is the **inside ratio** - the percentage of drawn points that fall
inside letter boundaries.

```swift
func calculateAccuracy(session: TracingSession) -> CGFloat {
    let allPoints = session.strokes.flatMap { $0.points }
    guard !allPoints.isEmpty else { return 0.0 }

    let insideCount = allPoints.filter { $0.isInsideLetter }.count
    return CGFloat(insideCount) / CGFloat(allPoints.count)
}
```

### 6.2 Coverage Bonus (Optional Enhancement)

To reward children who trace all the letters (not just part of the text), a coverage
metric can be added:

1. Divide the mask bitmap into a grid of cells (e.g., 4x4 pixels per cell)
2. Mark which cells contain letter pixels
3. After tracing, check which letter-cells received at least one stroke point
4. Coverage = (touched letter-cells) / (total letter-cells)

Final score = `(accuracy * 0.7) + (coverage * 0.3)`

This prevents gaming the system by carefully tracing a single letter perfectly and
ignoring the rest.

### 6.3 Edge Tolerance

At lower levels (1-3), apply a small tolerance zone around letter edges (2-4 pixels)
where strokes are still considered "inside." This accounts for the imprecision of
younger children and the visual ambiguity at letter boundaries. The tolerance shrinks
to 0 at higher levels.

```swift
func isInsideLetter(point: CGPoint, mask: PixelBuffer, level: Int) -> Bool {
    let tolerance = max(0, 4 - (level / 2))  // Levels 1-3: 3-4px, levels 8+: 0px
    // Check the point and surrounding pixels within tolerance radius
    for dx in -tolerance...tolerance {
        for dy in -tolerance...tolerance {
            let px = Int(point.x) + dx
            let py = Int(point.y) + dy
            if mask.isLetterPixel(x: px, y: py) {
                return true
            }
        }
    }
    return false
}
```

---

## 7. Data Persistence

Using SwiftData (iOS 17+) for local storage:

```swift
@Model
class PlayerProgress {
    var firstName: String = ""             // Entered on first launch
    var currentLevel: Int = 1
    var totalStars: Int = 0
    var totalPoints: Int = 0
    var currentStreak: Int = 0
    var lastPlayedDate: Date?
    var totalAttempts: Int = 0
    var earnedBadgeIDs: [String] = []
    var purchasedRewardIDs: [String] = []
}

@Model
class AttemptRecord {
    var date: Date
    var text: String
    var level: Int
    var accuracy: CGFloat
    var coverage: CGFloat
    var starsEarned: Int
    var pointsEarned: Int
}
```

No network connectivity or cloud sync is required for the single-user design.
All data lives on-device.

---

## 8. Settings

Accessible from the dashboard gear icon:

- **Change name** - Edit the child's first name (displayed at the top of the settings
  list; tapping opens a text field pre-filled with the current name)
- **Left-handed mode** - Mirrors UI controls to the left side for left-handed children
- **Sound effects** - Toggle on/off
- **Haptic feedback** - Toggle on/off (provides subtle haptics when going outside
  letter boundaries)
- **Reset progress** - Requires parent confirmation (long-press + confirm dialog)
- **Parental gate** - Simple math problem to prevent accidental resets
- **Guide line visibility** - Toggle the notebook-paper ruled lines on/off

---

## 9. Visual Design Guidelines

### 9.1 Color Palette

| Role              | Color                    | Hex       |
|-------------------|--------------------------|-----------|
| Inside stroke     | Bright green             | `#34C759` |
| Outside stroke    | Bright red               | `#FF3B30` |
| Guide text        | Black (80% opacity)      | `#000000` |
| Baseline rules    | Light gray               | `#E5E5EA` |
| Primary action    | Blue                     | `#007AFF` |
| Background        | Warm off-white           | `#FAF8F5` |
| Stars (earned)    | Gold                     | `#FFD700` |
| Stars (unearned)  | Light gray               | `#D1D1D6` |

### 9.2 Typography

- UI elements: `SF Pro Rounded` (medium weight) for buttons, labels, headings
- Guide text: Custom educational handwriting font (or `SF Pro Rounded` as fallback)
- Numbers/scores: `SF Pro Rounded` (bold) for emphasis

### 9.3 Animations

- **Microphone pulse:** Concentric rings expanding outward during dictation
- **Ink reveal:** Guide text fades out over 0.5s, leaving colored ink
- **Star award:** Each star drops in with a bounce, accompanied by a chime
- **Badge unlock:** Badge icon scales up from 0 with a spring animation + particle burst
- **Level up:** Full-screen confetti shower + large level number zooming in
- **Streak fire:** Flame icon flickers with a subtle animation on the dashboard

### 9.4 Sound Design

- Soft pencil-scratching sound while drawing (optional, tied to Apple Pencil pressure)
- Gentle "ding" for each star earned
- Ascending chime sequence for 3-star rating
- Triumphant horn for level-up
- Badge unlock has a unique notification sound

---

## 10. Accessibility

- VoiceOver support for all UI controls (tracing screen announces guide text)
- Dynamic Type for UI labels (not guide text, which is level-controlled)
- High contrast mode respected for UI chrome
- Reduce Motion support (disables confetti and complex animations)
- The red/green ink colors were chosen for brightness contrast; for colorblind users,
  the inside/outside distinction is also conveyed by:
  - Different stroke textures (solid for inside, dashed for outside) as an option
  - Haptic feedback when drawing outside letters
  - Alternative color schemes available in settings (blue/orange mode)

---

## 11. Screen Specifications

### 11.0 Welcome Screen (First Launch)

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                                                              │
│                  Welcome to TraceRight!                       │
│                                                              │
│                                                              │
│              What's your first name?                         │
│                                                              │
│              ┌────────────────────────┐                      │
│              │  Emma                  │                      │
│              └────────────────────────┘                      │
│                                                              │
│              ┌───────────────────┐                            │
│              │                   │                            │
│              │    Let's Go!      │                            │
│              │                   │                            │
│              └───────────────────┘                            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

- Only shown once on first launch (or after a progress reset)
- The text field is large, centered, and uses a child-friendly font
- "Let's Go!" button is disabled until at least 1 character is entered
- Input is trimmed of leading/trailing whitespace on submit
- Maximum name length: 20 characters

### 11.1 Home/Dashboard Screen

```
┌──────────────────────────────────────────────────────────────┐
│                                                    [⚙]       │
│                                                              │
│               Hi, Emma!                                      │
│               🔥 5-Day Streak                                │
│                                                              │
│         ┌─────────────────────────────┐                      │
│         │  LEVEL 3                    │                      │
│         │  ████████████░░░░░░  67%    │                      │
│         │  15 / 27 stars to Level 4   │                      │
│         └─────────────────────────────┘                      │
│                                                              │
│              ┌───────────────────┐                            │
│              │                   │                            │
│              │   Start Writing   │                            │
│              │                   │                            │
│              └───────────────────┘                            │
│                                                              │
│         Total Points: 2,450                                  │
│                                                              │
│  ── Badges ──────────────────────────────────────            │
│  [🏆] [🎯] [🔥] [░░] [░░] [░░] [░░] [░░]  ▸               │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 11.2 Dictation Screen

```
┌──────────────────────────────────────────────────────────────┐
│  [← Back]                                                    │
│                                                              │
│            What do you want to write, Emma?                   │
│                                                              │
│                                                              │
│                     ┌──────┐                                 │
│                     │  🎤  │  ◀── Tap to start               │
│                     └──────┘                                 │
│                                                              │
│              "The quick brown fox"                            │
│               ▲ live transcription                           │
│                                                              │
│         [Try Again]              [Done ▸]                    │
│                                                              │
│                                           [⌨ Type instead]  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 11.3 Tracing Screen

```
┌──────────────────────────────────────────────────────────────┐
│  Level 3       ☆ ☆ ☆           [Undo] [Clear]  [Done ✓]    │
├──────────────────────────────────────────────────────────────┤
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │
│                                                              │
│   T h e   q u i c k   b r o w n                             │
│ ─────────────────────────────────────────────────────────    │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │
│                                                              │
│   f o x   j u m p s                                          │
│ ─────────────────────────────────────────────────────────    │
│                                                              │
│                                                              │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│  Live accuracy: 78%                      Points: +120        │
└──────────────────────────────────────────────────────────────┘
```

### 11.4 Results Screen

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                  Great job, Emma!                             │
│                                                              │
│                    ★ ★ ☆                                     │
│                  2 out of 3                                  │
│                                                              │
│               ┌──────────────┐                               │
│               │              │                               │
│               │     78%      │  ◀── animated ring            │
│               │   Accuracy   │                               │
│               │              │                               │
│               └──────────────┘                               │
│                                                              │
│              + 190 points earned                             │
│                                                              │
│    🏆  NEW BADGE: "Sharp Shooter"                            │
│                                                              │
│                                                              │
│    [Try Again]    [New Sentence]    [Home]                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 12. Technical Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| PencilKit does not support per-point coloring | High | Use hybrid approach: PencilKit for input, custom renderer for display |
| Speech recognition accuracy for children's voices | Medium | Provide manual text entry fallback; use on-device recognition for lower latency |
| Mask generation performance for large text | Low | Generate mask once on screen load; bitmap lookup is O(1) per point |
| Font weight availability across all 8+ weights | Medium | Bundle a custom font; use SF Pro Rounded as fallback which supports all weights |
| Apple Pencil latency with custom rendering | Medium | Use Metal for stroke rendering if Core Graphics is too slow; target < 8ms per frame |
| Children may draw in wrong order or skip letters | Low | Scoring is purely positional (inside/outside), not order-dependent |

---

## 13. Future Enhancements (Out of Scope for v1)

- **Multiple user profiles** with iCloud Family Sharing
- **Letter-by-letter guided mode** that highlights the next letter to trace
- **Stroke order guidance** showing numbered arrows for letter formation
- **Classroom/teacher mode** with progress reports for multiple students
- **Curriculum alignment** with grade-specific letter sets (cursive in later grades)
- **Parent dashboard** with progress analytics and session history
- **Sharing** - export the reveal image to Photos or share with family
- **Adaptive difficulty** - automatically adjust level based on rolling average accuracy
  instead of (or in addition to) star-gated progression

---

## 14. File Structure

```
TraceRight/
├── TraceRight.xcodeproj
├── TraceRight/
│   ├── App/
│   │   ├── TraceRightApp.swift            # App entry point
│   │   └── ContentView.swift              # Root navigation
│   ├── Views/
│   │   ├── WelcomeView.swift              # First-launch name entry
│   │   ├── DashboardView.swift            # Home screen
│   │   ├── DictationView.swift            # Voice input screen
│   │   ├── TracingView.swift              # Core tracing experience
│   │   ├── TracingCanvasView.swift        # UIViewRepresentable for PencilKit
│   │   ├── RevealView.swift               # Ink-only reveal animation
│   │   ├── ResultsView.swift              # Score display
│   │   ├── SettingsView.swift             # App settings
│   │   └── Components/
│   │       ├── StarRatingView.swift       # Reusable star display
│   │       ├── BadgeView.swift            # Single badge display
│   │       ├── BadgeShowcaseView.swift    # Horizontal badge scroll
│   │       ├── ProgressRingView.swift     # Animated circular progress
│   │       ├── StreakView.swift           # Flame + day count
│   │       └── LevelProgressView.swift   # Level bar with star count
│   ├── ViewModels/
│   │   ├── GameStateViewModel.swift       # Central game state
│   │   ├── DictationViewModel.swift       # Speech recognition logic
│   │   └── TracingViewModel.swift         # Tracing session management
│   ├── Services/
│   │   ├── SpeechRecognitionService.swift # SFSpeechRecognizer wrapper
│   │   ├── MaskRenderer.swift             # CoreText → bitmap mask
│   │   ├── StrokeColorizer.swift          # Per-point inside/outside check
│   │   ├── ScoringEngine.swift            # Accuracy, stars, points calc
│   │   ├── BadgeEngine.swift              # Badge unlock logic
│   │   └── HapticsService.swift           # Haptic feedback manager
│   ├── Models/
│   │   ├── PlayerProgress.swift           # SwiftData model
│   │   ├── AttemptRecord.swift            # SwiftData model
│   │   ├── TracingSession.swift           # In-memory tracing data
│   │   ├── Badge.swift                    # Badge definitions
│   │   ├── Level.swift                    # Level configuration
│   │   └── Reward.swift                   # Unlockable reward definitions
│   ├── Resources/
│   │   ├── Fonts/                         # Custom handwriting font files
│   │   ├── Sounds/                        # Sound effect audio files
│   │   └── Assets.xcassets                # Colors, images, badge icons
│   └── Utilities/
│       ├── Constants.swift                # App-wide constants
│       └── Extensions.swift               # Swift/UIKit extensions
├── TraceRightTests/
│   ├── ScoringEngineTests.swift
│   ├── MaskRendererTests.swift
│   ├── StrokeColorizerTests.swift
│   └── BadgeEngineTests.swift
└── TraceRightUITests/
    └── NavigationFlowTests.swift
```

---

## 15. Development Phases

**Phase 1 - Core Tracing Engine**
- Mask rendering from text
- PencilKit input capture
- Custom colored stroke rendering
- Inside/outside detection
- Basic tracing screen with single-line text

**Phase 2 - Welcome + Dictation + Multi-line**
- Welcome screen with name entry (first-launch flow)
- Personalized greetings and messages using the child's name
- Speech recognition integration
- Multi-line text layout with baselines
- Dictation screen UI
- Text flow between screens

**Phase 3 - Scoring + Reveal**
- Accuracy calculation
- Star rating system
- Reveal animation (fade out guide text)
- Results screen

**Phase 4 - Gamification**
- Level progression (font size/weight scaling)
- Points system
- Daily streak tracking
- Badge definitions and unlock logic
- Dashboard with all gamification elements

**Phase 5 - Polish**
- Animations and transitions
- Sound effects
- Haptic feedback
- Settings screen
- Accessibility audit
- Edge tolerance tuning per level
- Unlockable rewards store

---

*Document version: 1.1*
*Last updated: 2026-02-05*
