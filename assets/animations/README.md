# Animation Setup Guide

## Step 1: Get Animations from Mixamo

1. Go to [mixamo.com](https://www.mixamo.com/) and create a free account
2. Click "Upload Character" and upload your `Male.glb` file from `assets/models/Avatar/`
3. Wait for auto-rigging to complete
4. Browse animations and download these essential ones:

### Recommended Animations:
| Animation | Search Term | Settings |
|-----------|-------------|----------|
| Idle | "Idle" or "Breathing Idle" | Loop: Yes |
| Walking | "Walking" | Loop: Yes |
| Running | "Running" or "Jogging" | Loop: Yes |
| Jump | "Jump" | Loop: No |
| Fall | "Falling Idle" | Loop: Yes |

### Download Settings:
- **Format:** FBX for Unity (.fbx)
- **Skin:** Without Skin ✓ (Important!)
- **Keyframe Reduction:** none
- **FPS:** 30

## Step 2: Import Animations to Godot

1. Place downloaded `.fbx` files in this folder (`assets/animations/`)
2. Godot will auto-import them
3. Double-click each `.fbx` file in Godot's FileSystem panel
4. In the Import dock, configure:
   - Animation > Import: ✓ Enabled
   - Animation > Loop Mode: Linear (for looping anims)

## Step 3: Add Animations to Your Character

### Option A: Using AnimationPlayer (Simple)

1. Open your `Male.glb` scene (double-click in Godot)
2. Click "Make Local" to save as a new scene
3. Find the `AnimationPlayer` node
4. For each animation FBX:
   - Open the FBX in another tab
   - Find the AnimationPlayer inside it
   - Copy the animation
   - Paste into your Male's AnimationPlayer
5. Rename animations to: `Idle`, `Walking`, `Run`, `Jump`, `Fall`

### Option B: Using Animation Library (Recommended)

1. Open your `Male.glb` scene
2. Select the `AnimationPlayer` node
3. In Animation panel, click the folder icon (Animation Library)
4. Click "Load Library" 
5. Navigate to your FBX animation files
6. This imports all animations at once!

## Step 4: Test Your Animations

The player controller is already set up to handle these animations:
- **Idle** - plays when standing still
- **Walking** - plays when moving slowly
- **Run** - plays when holding Sprint (Shift by default)
- **Jump** - plays when jumping
- **Fall** - plays when falling

## Troubleshooting

### Animation doesn't play
- Check that animation names match exactly: `Idle`, `Walking`, `Run`, `Jump`, `Fall`
- Make sure AnimationPlayer node is named `AnimationPlayer`

### Character deforms weirdly
- Ensure you downloaded animations "Without Skin"
- The skeleton must match between model and animation

### Animation is too fast/slow
- Adjust the animation speed in AnimationPlayer
- Or modify the Speed Scale property

## Alternative: Ready Player Me Animations

If your avatar is from Ready Player Me:
1. Visit [readyplayer.me/developers](https://readyplayer.me/developers)
2. Download their animation pack (compatible with your avatar)
3. Import the same way as Mixamo animations
