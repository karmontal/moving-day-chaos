# Intro story (Steam teaser)

| File | Content |
|---|---|
| `01_panel.png` … `06_panel.png` | Story panels (Higgsfield `gpt_image_2_5`, refs: key art + the four crew images): lazy office → phone rings → the call → alarm button → fire-pole rush (Zoom smashes the vase, Bean breaks the chair) → truck bursts out |
| `end_card.png` | Logo card ("Wishlist on Steam") |
| `intro_story.mp4` | 33.5 s, 1920×1080: panels animated with Kling 3.0 (silent), our `job.ogg` music, generated gibberish voices and SFX |

Rebuild: put the six Kling clips here as `clip_1.mp4` … `clip_6.mp4` (job ids below) and run
`python3 tools/make_story_video.py`.

Image jobs: 379f9849, 7c6f7fb7, cd81c0fe, 9176fa59, e7340561, 1a2c4252 ·
Video jobs: 9ae1fd00, 9d71b227, 4ea95147, 14d9d229, 52ab32f2, 4ef395bc

**Steam note:** the store's first trailer must mostly show real gameplay. Use this as the opening
(or a second "story" trailer) and follow it with gameplay capture. Declare AI-generated art in the
Steam content survey.
