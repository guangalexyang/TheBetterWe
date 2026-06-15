# 佳家 (TheBetterWe) — Mockup Design Reference

Source: `/Users/alexyang/Downloads/TheBetterWe` — React/Tailwind web prototype  
Generated: 2026-06-14

This document captures the visual design, layout, and interaction patterns from the interactive mockup so the iOS team can match it precisely.

---

## Design Tokens

### Color Palette

| Token | Light | Dark |
|-------|-------|------|
| Page background | `#fdf8f5` (warm cream) | `#1a1210` (deep ember) |
| Card surface | `#ffffff` | `#231815` |
| Popover surface | `#ffffff` | `#2a1e1a` |
| Primary accent | `#f0704a` (coral-orange) | `#f0704a` (same) |
| Muted fill | `#f5ede8` | `#2d1f1a` |
| Muted text | `#9b7b6f` | `#a08070` |
| Border | `rgba(240,112,74, 0.12)` | `rgba(255,255,255, 0.08)` |
| Input background | `#fef5f1` | `#2d1f1a` |
| Body text | `#2d1f1a` | `#f0e8e4` |
| Destructive | `#e53e3e` | `#e53e3e` |

### Semantic Colors (fixed, not theme-switched)

| Use | Value |
|-----|-------|
| Earn / add points | bg `#e8f7f0`, text `#1a7a52` |
| Deduct points | bg `#fde8df`, text `#c0471f` |
| Redeem reward | bg `#f3e8ff`, text `#7c3aed` |
| Add-points button | `linear-gradient(135deg, #52b88a, #3da67a)` |
| Deduct-points text | `#c0471f` |

### Page Background Gradients

**Light:**
```
linear-gradient(160deg, #fdf8f5 0%, #fef0ea 50%, #fdf5fb 100%)
```

**Dark:**
```
linear-gradient(160deg, #1a1210 0%, #231510 50%, #1e1218 100%)
```

### Primary Button Gradient (+ button, confirm, voice mic)
```
linear-gradient(135deg, #f0704a 0%, #e85d7a 100%)
box-shadow: 0 4px 20px rgba(240,112,74, 0.4)
```

### Border Radius Scale

| Name | Value |
|------|-------|
| sm | 12px |
| md | 14px |
| lg | 16px (base `--radius`) |
| xl | 20px |
| 2xl | 24px |
| 3xl | 28–32px (cards, sheet top) |

### Typography

- **Font family:** Nunito (Google Fonts)
- **Base size:** 16px
- **Heading weights:** `h2` = 20px/600, `h3` = 18px/600, `h4` = 16px/600
- **Body / label:** 16px/400
- **Micro:** 12px (captions, badges, timestamps)

---

## Theme Switching

- Toggled via a `.dark` class on `<html>`.
- Persisted to `localStorage` under key `jiajia-theme` (`"dark"` | `"light"`).
- **iOS mapping:** `ThemeManager.isDark` writes to `UserDefaults`; `AppTheme.dark` / `.light` static instances provide the same token values.
- Toggle control lives in the **Me → 账户设置** row ("深色模式") as a pill-style toggle switch — active state uses primary coral (`#f0704a`) fill.

---

## App Shell

### Bottom Tab Bar

Three columns: left tab | center + | right tab.

```
┌──────────────────────────────────────────┐
│  首页          [+]           我的         │
│  ▼                                        │
└──────────────────────────────────────────┘
```

- **Left / Right tabs:** icon (22px) + label (10px) + active dot (4px circle, primary).
  - Active: primary coral, bold label.
  - Inactive: `#9b7b6f` (muted-foreground).
- **Center + button:** 56×56pt `rounded-2xl`, primary gradient, white `plus` icon (26px/2.5 weight), shadow `0 4px 20px rgba(240,112,74,0.4)`. Lifts 5pt above bar baseline (`-mt-5`).
- **Bar background:** `rgba(255,255,255,0.92)` light / `rgba(35,24,21,0.92)` dark, `backdrop-blur`.
- **Top separator:** 0.5px `border` in `border-color`.
- Bottom safe area respected via `env(safe-area-inset-bottom)`.

---

## Home Screen (HomeScreen.tsx)

### Top Navigation Bar

```
┌─────────────────────────────────────────────────────┐
│  ☰   [主页]  [积分系统]                              │
└─────────────────────────────────────────────────────┘
```

- **Hamburger (☰):** 36×36pt `rounded-xl`, opens `LeftDrawer` (slides from left).
- **Module tab pills:** horizontally scrollable, no scrollbar shown. Active pill = primary fill + white bold text; inactive = transparent + muted text + hover muted bg.
- Bar: `bg-background/80` + `backdrop-blur-xl` + bottom border.

### Module Tabs

| Key | Label | Content |
|-----|-------|---------|
| `dashboard` | 主页 | `DashboardView` |
| `points` | 积分系统 | `PointSystemView` |

Transitions: slide `opacity + x` with Framer Motion `AnimatePresence` mode `"wait"` (duration 0.2s). Dashboard exits to the right (+x), Points enters from the right (+x).

---

## Dashboard View (DashboardView.tsx)

Scrollable vertical list of **draggable widget cards**. Default order: Points → Todo → Highlight.

### Card Shell

```
rounded-3xl
bg-card
border border-border
px-4 pt-4 pb-4
shadow-sm
```

Each card has a `GripVertical` handle (16px, muted, 40%) in the top-right for drag-reorder. Reorder uses `Reorder.Group` / `Reorder.Item` (Framer Motion).

---

### Widget: 积分系统 (PointsWidget)

```
┌─────────────────────────────────────────────────────┐
│  [⭐ amber] 积分系统           管理 ›               │
│  ┌──────────────────────────────────────────┐       │
│  │  👦  小明          ████░░░░  240  分  ›  │       │
│  │  👧  小红          ███░░░░░  185  分  ›  │       │
│  └──────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

- Section header: 28×28pt `rounded-lg` amber-100 icon bg + amber-500 star icon; bold 14px label; "管理 ›" link in primary, 12px.
- Each child row: child-color avatar bg (`color+"22"`), name bold 14px, progress bar 24pt wide in child color, points in child color bold 18px, chevron.
- Tapping a row opens the full `PointSystemView` for that child.
- "管理" link switches to the `points` module tab.

---

### Widget: 家庭待办 (TodoWidget)

```
┌─────────────────────────────────────────────────────┐
│  [📋 blue] 家庭待办               1/3 完成          │
│  ○  购买本周蔬菜                                     │
│  ○  预约周末亲子活动                                  │
│  ✓  清洁浴室  (strikethrough, muted)                 │
└─────────────────────────────────────────────────────┘
```

- Max 4 items shown (pending first, then done).
- Checkbox: 20×20pt circle, 2px border (`muted-foreground/40`); checked = primary fill + white check (11px).
- Toggle is optimistic (client-only in mockup; in iOS this hits server).

---

### Widget: 今日亮点 (HighlightWidget)

```
┌─────────────────────────────────────────────────────┐
│  [✨ rose] 今日亮点                                  │
│  ┌────────────────────────────────── [→] ┐          │
│  │  记录今天的美好…                         │         │
│  └────────────────────────────────────── ┘          │
│  👩  妈妈                                            │
│     小明今天自己收拾书包，完全不需要提醒！🌟          │
│  👨  爸爸                                            │
│     全家一起做了饺子，好开心～🥟                     │
└─────────────────────────────────────────────────────┘
```

- Input: `rounded-xl`, muted bg, `text-sm`, Send icon (14px) in primary (disabled opacity 0.3).
- Max 2 highlights shown. Each: emoji avatar (text, 18px) + author micro label + text body 14px.

---

## Point System View (PointSystemView.tsx)

Full-screen module (replaces Dashboard in the tab slot). Accessed from the "积分系统" tab or tapping a child in PointsWidget.

### Hero Header

```
┌─────────────────────────────────────────────────────┐
│  ‹ 返回                                              │
│  [小明]  [小红]                ← child selector      │
│                                                      │
│  👦 (56pt rounded-2xl white/25 bg)                   │
│  当前积分  240  分                                    │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │  🏆 乐高机器人            240/500            │    │
│  │  ████████░░░░░░░░░░░░░░░░░░░░░             │    │
│  │  还差 260 分                                 │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

- Background: `linear-gradient(135deg, child.color, child.color+"cc")`.
- Child selector pills: active = `bg-card text-foreground font-bold`; inactive = `bg-white/20 text-white`.
- Score: 36px black Nunito, label `text-white/80` 12px.
- Goal card: `bg-white/20 rounded-2xl px-4 py-3`. Progress bar `h-2 rounded-full bg-white` animated with Framer Motion (0 → target, 0.7s easeOut).

### Action Row

```
[ ✚ 加分 ]  [ — 扣分 ]  [ 🎤 ]
```

- Add: `flex-1`, green gradient (`#52b88a → #3da67a`), `rounded-2xl`, white text bold 14px.
- Deduct: `flex-1`, muted bg, text `#c0471f` bold 14px.
- Mic: 44×44pt `rounded-2xl`, muted bg, muted-foreground icon — opens `VoiceSheet`.
- Row: `bg-card border-b border-border px-4 py-3`.

### Tabs

`积分记录` | `奖励兑换` — underline style, primary color when active.

### History Tab (积分记录)

Each row: `bg-card border border-border rounded-2xl px-4 py-3 shadow-sm`.
- Left: 36×36pt `rounded-xl` colored bg (semantic: earn/deduct/redeem) + emoji icon.
- Center: reason text 14px + timestamp 12px muted with Clock icon.
- Right: `±amount` in semantic text color, bold 14px.
- New rows animate in: `opacity: 0 → 1, x: -12 → 0`.

### Rewards Tab (奖励兑换)

2-column grid. Each card: `bg-card border rounded-2xl p-4 shadow-sm`.
- Emoji icon 24px, name bold 14px, cost row (amber Star + "X 积分" 12px).
- Redeem button: primary coral, `rounded-xl`, 12px bold white. Disabled: `opacity-40` + label "积分不足".

### Add / Deduct Modal (bottom sheet)

Spring animation (damping 28, stiffness 320), slides from bottom.

```
┌─────────────────────────────────────────────────────┐
│            ─────                                     │
│  🌟 给 小明 加分                                     │
│  [ 5 ]  [ 10 ]  [ 15 ]  [ 20 ]  [ 30 ]             │
│  ┌───────────────────────────────────────┐          │
│  │              10                       │          │
│  └───────────────────────────────────────┘          │
│  ┌───────────────────────────────────────┐          │
│  │  原因（如：主动帮忙做饭）               │         │
│  └───────────────────────────────────────┘          │
│  [ 确认加分 ]                                        │
└─────────────────────────────────────────────────────┘
```

- Quick-pick chips: active = `bg-primary text-white`, inactive = muted.
- Amount input: `text-2xl font-black text-center`, input-background fill.
- Confirm button: gradient matches action type (green for earn, coral-pink for deduct).
- Backdrop: `bg-black/30`, closes on tap.

---

## Me View (MeView.tsx)

Scrollable settings page.

### Profile Hero Card

```
┌──────────────────────────────────────────────────┐
│  👩 (64pt rounded-2xl, gradient-tinted bg)        │
│  李妈妈                                            │
│  家长 · 李家大家庭                                  │
│  [管理员]  ← primary/10 bg, primary text, pill    │
└──────────────────────────────────────────────────┘
```

`bg-card border border-border rounded-3xl p-5 shadow-sm`.

### Settings Sections

Section label: 12px muted-foreground, `px-1 mb-2`.

Settings group: `bg-card border border-border rounded-2xl overflow-hidden shadow-sm`.
Each row: icon (28×28pt `rounded-lg`, color+"22" bg), label 14px flex-1, chevron or control. `border-b border-border` between rows.

**账户设置 rows:**
1. 个人信息 — icon `#4a90d9`
2. 通知与提醒 — icon `#f0704a`
3. 深色模式 — pill toggle switch (44×24pt `rounded-full`; active fill = primary; knob = white 20pt circle, transitions left/right)

**关于 rows:**
1. 隐私政策 — icon `#52b88a`
2. 帮助与反馈 — icon `#f7c948`

Footer: `v1.0.0 · TheBetterWe` centered, 12px muted.

---

## Voice Sheet (VoiceSheet.tsx)

Bottom sheet, same spring animation as Point System modal. `bg-card rounded-t-3xl`. Max-width 480px centered.

Sheet header: "语音指令" h3 (left) + X close button (right).

### Phase: idle

```
说出指令，例如：
"给小明加十分，因为他帮忙洗碗"

       [🎤]         ← 80×80pt, primary gradient, rounded-full

    点击开始录音
```

### Phase: recording

- Primary text "正在聆听…" above mic button.
- Mic button: pulsing ring (`bg-primary/20`, scale 1→1.25→1, 1.2s infinite).
- **Waveform:** 20 vertical bars (6pt wide, `rounded-full`, `bg-primary/60`), each animates height `4 → rand(4–36) → 4` independently (0.5–1s, staggered 0.05s).

### Phase: processing

- Spinner: 48pt circle, 3px border `border-primary/30 border-t-primary`, rotates 360° at 1s/loop.
- "正在解析指令…" muted text below.
- Transcript card: muted rounded-2xl bg, label "识别结果" 12px muted, transcript text in quotes 14px.

### Phase: result

- Transcript card (same as processing).
- **Intent card:** colored bg + border by action type (earn/deduct/redeem). Emoji (24px) + bold action label + colored amount + "→ childName" + reason 12px muted.
- Two buttons: "重试" (muted bg, muted text) | "确认执行" (green gradient).

### Phase: confirmed

- 64pt white circle `bg-green-100` with ✅ emoji, scales in from 0.
- "指令已执行！" bold text.
- Auto-closes after 1s.

---

## Left Drawer (LeftDrawer.tsx)

Slides in from the left edge. Width: 72 (288pt). `bg-card shadow-2xl`.

Backdrop: `bg-black/30`, closes on tap. Spring animation (damping 28, stiffness 300).

### Drawer Header

```
linear-gradient(135deg, #f0704a, #e85d7a)
px-5 pt-12 pb-6
```

- Family label: "家庭" 12px white/70 micro + family name h2 white + family emoji.
- X close button: top-right, white/70 → white on hover.
- Member avatar stack: overlapping circles (`-space-x-2`), each 32pt `rounded-full border-2 border-white`, child-color+"44" bg.

### Drawer Content (scrollable)

**家庭成员 section:**
Each member row: 36pt `rounded-xl` avatar (`color+"22"`), name bold 14px, role 12px muted. No chevron.

**家庭设置 section:**
Rows in a card (`bg-card border border-border rounded-2xl overflow-hidden`):
- 编辑家庭名称 — `#4a90d9`
- 邀请成员 — `#52b88a`
- 管理成员权限 — `#f7c948`
- 通知设置 — `#f0704a`

**模块管理 section:**
Same card shell. Each row: emoji icon + label + status badge.
- Enabled: `text-green-600 bg-green-50 px-2 py-0.5 rounded-full text-xs` "已启用"
- Coming soon: muted bg + muted text "即将推出"

Modules shown: 待办事项 ✓ | 积分系统 ✓ | 今日亮点 ✓ | OrderFromMe (coming) | RewardMe (coming)

### Drawer Footer

Border-top separator, `px-4 pb-8 pt-4`.
- Log out: full-width button, `text-destructive`, hover `bg-red-50`, left-aligned LogOut icon + "退出登录" 14px.

---

## Animation Patterns

| Pattern | Implementation |
|---------|----------------|
| Module tab switch | `AnimatePresence mode="wait"` + `opacity 0→1, x ±20 → 0`, 0.2s |
| Bottom sheet open | `y: "100%" → 0`, spring damping 28 stiffness 320 |
| Left drawer open | `x: "-100%" → 0`, spring damping 28 stiffness 300 |
| Widget drag reorder | Framer Motion `Reorder.Group / Reorder.Item` |
| Goal progress bar | `width: 0 → X%`, 0.7s easeOut on mount |
| Activity row appear | `opacity 0 → 1, x -12 → 0` |
| Mic pulse ring | `scale: 1 → 1.25 → 1`, 1.2s infinite |
| Waveform bars | `height: 4 → rand → 4`, 0.5–1s infinite, staggered per bar |
| Confirmed checkmark | `scale: 0 → 1` on mount |
| Dark mode toggle knob | CSS `transition-all duration-200`, left offset |

---

## iOS Implementation Notes

### Color Mapping (mockup → AppTheme tokens)

| Mockup CSS var | iOS AppTheme field |
|----------------|--------------------|
| `--background` | `theme.pageBg` |
| `--card` | `theme.cardSurface` |
| `--border` | `theme.cardBorder` |
| `--primary` | `theme.primaryAccent` |
| `--muted` | no direct token — use `Color(.systemGray6)` |
| `--muted-foreground` | `.secondary` / `.tertiary` |

Page bg gradient: `LinearGradient(colors: theme.pageBgGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()`.

### Components Not Yet in iOS

Based on the mockup, these UI elements exist in the web prototype but have not been confirmed implemented in SwiftUI:

1. **Dashboard widget drag-reorder** — `Reorder.Group` analog → `List` with `.onMove` or custom drag gesture
2. **Highlight widget inline input** — quick text entry on dashboard card
3. **Point System rewards tab** — 2-col grid of redeemable rewards
4. **Left drawer module management section** — module enable/disable list
5. **MeView profile hero card** — "管理员" role badge, avatar

### Feature Toggle Mapping

| Module | Toggle key | Current server state |
|--------|------------|----------------------|
| 家庭待办 | `familyTodo` | **off** |
| 今日亮点 | `familyNotes` | **off** |
| OrderFromMe | `orderFromMe` | **off** |
| 积分系统 | always on | — |
