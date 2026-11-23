# MyPet: the full guide

For a new owner, a tester, a marker or a team member opening MyPet for the first time. It covers what MyPet is and is not, how to use every part, a demo script you can follow on stage or in a screen recording, what data it needs, its limits, and the questions people actually ask.

Last updated 20 Nov 2026 (app commit da59032).

---

## 1. What MyPet is, in one paragraph

MyPet is a free phone app for cat and dog carers. Each evening you log three things in three taps: did your pet eat (all, some or none), its energy (1 to 5) and whether toileting was normal. After 7 days MyPet learns what is usual for **your** pet, and quietly points out a change that lasts ("Energy lower than Biscuit's usual on 2 of the last 3 days"). A short video "check" reads a 5 to 10 second clip (sound and picture) on the phone and suggests a likely feeling, such as happy or uneasy. Everything stays on the phone, and before a vet visit you can share a one-page PDF of the record.

**MyPet never diagnoses.** It never names an illness, never gives a probability of one, and every change it shows carries "Not a medical diagnosis. If you are worried, talk to your vet."

## 2. Why it works this way (the research in short)

- **Owners notice change late.** Cats in particular hide discomfort, and slow changes (a kilo lost over three months, a little less food each week) are absorbed into "normal". A daily log turns a feeling into evidence a vet can use.
- **Compare a pet only with itself.** Pets differ hugely: a sleepy senior cat and a Border Collie puppy have nothing in common. MyPet never uses a breed table or a population threshold for flags. It compares the last 3 days with the pet's own previous 28 days (14 for pets under 6 months), using the median and the median absolute deviation, which shrug off one odd day (Leys et al. 2013).
- **A change must last.** One bad day is life. A flag needs 2 of the last 3 days to be unusual for that pet, and nothing is shown before 7 days of logs.
- **Food as a share, weight as a trend.** 5 g of dry food is 8% of a kitten's day and 1% of a Labrador's (AAHA 2021 and Pet Nutrition Alliance energy formula, RER = 70 x kg^0.75). So food is logged as All / Some / None, a share of the pet's own portion, and weight is followed as a trend line through every weigh-in, with a noise floor of 1.5% of body weight or 0.05 kg, whichever is larger.
- **Baselines move with the pet's life.** Growing pets are expected to gain (MyPet only notes it if growth stops for 2 weeks), seniors get a slow 90-day weight comparison, days within 2 days of a vet visit or vaccination are left out of the comparison, and "Something changed" (new food, a move, medicine) gives a measure a fresh start.
- **Day-1 safety net.** Before 7 days, MyPet can only count what you logged: "Did not eat 2 days in a row". That is a fact, not a comparison.
- **On the phone, free, no AI account.** The behaviour check uses small open models (CLAP for sound, a picture model for dogs) running on the phone. No generative AI, no paid tokens, nothing uploaded. Firebase Spark (free) only when sharing between carers arrives.

How well it does on synthetic data (300 pets with a planted change, 300 without, 60 days each): 92% of changes flagged within 7 days (eating 98%, toileting 100%, energy 79%), median 1 day after the change starts, and about 1 flag per 114 pet-days on pets with no change. No flag before 7 logged days. The behaviour check, on 80 real Wikimedia Commons clips: picture right 54/80, sound right 47/80, either right 66/80. That is why it says "likely", caps the shown confidence at "over 90%", and says "Not sure" when nothing stands out.

## 3. How to use MyPet

### Add a pet
Pets > Add. Name and cat or dog are all you need. Optional: breed, birth date (or "Not sure? Say about how old"), weight, photo, colour. Under "To get to know your pet": neutered, size when grown (dogs), usual portion in your own units, meals a day. Under "Extra daily questions": Drinking more than usual, Accident indoors, Vomited. Switch these on only for pets who need them (an older cat, a puppy in house training).

### Log a day (3 taps)
Today > Log now. "Same as last entry" fills Ate and Toileting from yesterday, so a routine day is: energy, Save.
- **Ate today:** All, Some or None.
- **Energy:** 1 (very low) to 5 (high). Under it: "Usual for Biscuit: 4", so you judge against your own pet.
- **Toileting normal:** Yes, No or Didn't see. "Didn't see" is honest and is never counted as a problem.
- Optional: weight, a note, and any extra questions you switched on.
- **By voice:** tap "Tell us about Mao's day" and talk: "Mao ate half her dinner, a bit tired, normal poo". The answers fill in as you speak, and you can correct yourself ("oh wait, she did finish it"). Name several pets in one go and each one's answers wait on their own log.
- Missed a day? Today shows one line, "3 days not logged · fill in Tue 17 Nov". Never a wall of red.

### Log without opening the app
- **The evening reminder:** press and hold it. "All normal" logs every pet not logged yet as a normal day at its usual energy. "Tell us about today" lets you type or dictate a sentence; MyPet reads it the same way as the voice log.
- **Siri and Shortcuts:** say "Tell MyPet about today" or "Everything normal in MyPet". In the Shortcuts app you can also put "Tell MyPet" on the Home Screen as a one-tap shortcut or widget, or on the Action button.

### Insights
After 7 days: the pet's usual range (the shaded band) and the last 7 or 30 days, Ate, and a Weight chart. A change shows as an amber card with the evidence: which measure, which direction, by how much, compared with which days. "Early sign" means fewer than 14 days to compare with. "Two days running" is a plain count. "Weight change" and "Slow change" are weight facts, both up and down. Before 7 days, Insights shows "Getting to know Coco": life stage, a rough daily energy range and what is typical for a pet that age, as context only.

### Check (behaviour)
Check > record 5 to 10 seconds (or choose a video). MyPet reads the sound and picture on the phone, then shows the likely feeling, the sounds it heard and the moments it found ("0:02 Hissing"). Save keeps the video, only the sound, or only the results, as set in Settings > Saved clips. Nothing is uploaded.

### The pet page
Big photo (tap to change), details, Daily log and Health record buttons, "Something changed", the typical-for-this-pet card, and the timeline. Tap a saved check to replay it. The PDF icon shares the record for the vet (with flags, a weight chart and the daily table). Health records can be filled from a vet's PDF.

## 4. Demo script (about 4 minutes, no editing needed)

More > Try a demo. Your own pets are never touched. In every story, Next moves to the exact part it talks about and outlines it; tap the pet's face to shrink the bubble, tap again to bring it back.

1. **"A dog not feeling well" (Biscuit, 7 steps).** Three-tap log, the 7-day rule, the amber energy flag on Today, the usual band on Insights, then Check plays Biscuit's howl as if just filmed and shows the result, the saved check on his page, and the vet PDF.
2. **"A cat off her food" (Mochi).** Ate went Some, then None: the flag on Today and Insights, Check plays her hiss at the vacuum, Settings > Saved clips (video, sound only, or results only).
3. **"A happy, healthy puppy" (Pepper).** Everything calm; his weight chart climbs every week and MyPet expects that.
4. **"A new kitten" (Bean).** Only 4 days of logs: Insights waits and shows "Getting to know Bean" instead.
5. **"Log by voice while driving" (Carl).** Carl's car on the road, then the view from his seat as MyPet's reminder arrives (with quiet road sound you can mute), then the daily log fills itself in as his voice note plays: Ate flips from None to All when he corrects himself, energy 2, toileting normal, 10.4 kg, the note. Then Save.

Tip for recording: on a Mac, run the app in the iPhone Simulator (iPhone 17 Pro Max) and use the Simulator's File > Record Screen, or QuickTime. The Simulator has no camera, so film real checks on the iPhone; the demo's Check steps play their clips without a camera.

## 5. What data MyPet needs, and what it keeps

| Data | Needed? | Where it lives |
|---|---|---|
| Pet name, cat or dog | Yes | On the phone |
| Breed, birth date, weight, neutered, portion, photo | Optional, helps the starter guide and growth mode | On the phone |
| Daily log: ate, energy, toileting (+ optional weight, note, extra checks) | 7 days before Insights | On the phone |
| Health records (vet visits, vaccinations, medicine) | Optional | On the phone |
| Check clips | Optional: video, sound only, or nothing (results only) | On the phone only, never uploaded |

Nothing is sent anywhere today. Sharing a pet between family members needs a small free cloud store (Firebase Spark) and is a later stage; until then each phone keeps its own pets. When two people log the same day on one phone, MyPet keeps any "No" and the lower energy, and each entry says who logged it.

## 6. Limits, honestly

- MyPet does not diagnose and cannot rule anything out. A calm Insights page is not a clean bill of health.
- Energy is a feeling on a 1 to 5 scale. Different carers score differently, so the same person logging helps.
- The behaviour check reads sound well for barks, howls, hisses, meows and purrs, and the picture model only for dogs. Cats get "a cat is in view" from the picture. Quiet pets give little to go on. It is a likely feeling, never certain.
- Weight from a bathroom scale is noisy; MyPet ignores changes inside the noise floor.
- The starter guide's energy range is a population formula. Your food bag and your vet know better.
- **Installing:** with a free Apple developer account the app must be reinstalled every 7 days. The current install stops opening on 27 Nov around 2:30 PM. The Simulator on a Mac does not expire.

## 7. FAQ (as a new owner would ask)

**Do I have to log every day?** No. Missed days stay missing, never counted as bad days. MyPet needs 7 logged days in total to start comparing.

**Why didn't it flag one bad day?** On purpose. A change has to show on 2 of the last 3 days. One off day is normal life.

**My puppy is gaining weight. Will it nag me?** No. Growing pets are expected to gain. It only notes if the weight stops going up for 2 weeks.

**We changed her food and now she eats less. Will it flag her?** Tap "Something changed" on her page and pick "New food or portion". Eating and weight start fresh from that day.

**She was quiet after her vaccination.** Days within 2 days of a vaccination or vet visit are left out of the comparison, and a flag that touches them says so.

**What does "Early sign" mean?** There were fewer than 14 days to compare with, so it is less certain.

**What does "Two days running" mean?** It is a plain count of what you logged, like "Did not eat 2 days in a row". It shows from day 1, before MyPet knows your pet's usual.

**Is my video uploaded?** Never. It is read on the phone. Settings > Saved clips decides if Save keeps the video, only the sound, or only the results.

**Why does it say "over 90%" and not 98%?** No short clip is that certain, so shown confidence is rounded and capped.

**Can my family log too?** Not across phones yet. That needs the free cloud stage. On one phone, everyone's logs are kept and merged safely.

**Does it work on a Mac?** Yes, in the iPhone Simulator (phone-sized, no camera) or as "Designed for iPad".

**Does it cost anything?** No. No subscription, no AI account, no paid tokens.

**Who made it?** FIT3162 team, Monash University, supervised by Dr Yam. Demo clips from Wikimedia Commons (credited in the app). Carl's demo voice is synthetic (Kokoro TTS, Apache 2.0).

## Sources

- AAHA 2021 Nutrition and Weight Management Guidelines for Dogs and Cats; Pet Nutrition Alliance calorie calculator (RER and life-stage factors).
- WSAVA Global Nutrition Guidelines (body condition, weight monitoring).
- Leys C. et al. (2013) Detecting outliers: Do not use standard deviation around the mean, use absolute deviation around the median.
- FIT3162 MyPet Pet Owner Review and Baselines (docs/), the team's report and requirements (FR, NFR IDs).
