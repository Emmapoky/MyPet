// Made-up vet documents for the demo pets (More > Try a demo), bundled as PDFs in
// assets/demo_pdfs and offered by "Fill from a vet PDF" during a demo. No real pet, owner,
// clinic or vet. tool/make_demo_pdfs.dart turns these texts into the PDFs.
//
// Some are complete, and some leave things out on purpose, so a demo can show MyPet asking
// for what is missing, a scanned page it cannot read, and a record for another pet.

/// One demo document: the PDF's file name, a short name for the picker, which demo pet
/// it belongs to, what it shows off in a demo, and its text.
class DemoDocument {
  const DemoDocument(this.file, this.label, this.pet, this.shows, this.text, {this.scanned = false});
  final String file, label;

  /// Demo pet name, or null for the tricky ones any pet can try.
  final String? pet;

  /// What it shows in a demo, such as "Complete" or "No date: MyPet asks for it".
  final String shows;
  final String text;

  /// Saved as a picture of the page, with no words to read (a phone scan).
  final bool scanned;
}

const demoDocuments = <DemoDocument>[
  // ---- Biscuit, Shiba Inu: low energy this week ----
  DemoDocument('biscuit-vaccination-2026.pdf', 'Vaccination certificate', 'Biscuit', 'Complete, with next due date', '''
Sunway Paws Veterinary Clinic
12 Jalan PJS 11/15, Bandar Sunway, Selangor  |  03-5611 2040
VACCINATION CERTIFICATE
Pet name: Biscuit  Species: Dog  Breed: Shiba Inu  Sex: Male (neutered)
Owner: Demo Carer
Date of vaccination: 03/11/2026
Vaccine  Product  Batch
Rabies  Nobivac Rabies  RB2291
DHPP  Nobivac DHPPi  DH8812
Leptospirosis  Nobivac L4  LP0921
Weight: 10.6 kg
Next due: 03/11/2027
Attending vet: Dr Aisha Rahman
'''),
  DemoDocument('biscuit-visit-low-energy.pdf', 'Visit: low energy', 'Biscuit', 'Complete visit summary with recheck', '''
Sunway Paws Veterinary Clinic
12 Jalan PJS 11/15, Bandar Sunway, Selangor  |  03-5611 2040
CONSULTATION SUMMARY
Patient: Biscuit  Species: Dog  Age: 5 years
Visit date: 19 November 2026
Reason for visit: Quiet and sleeping more for 3 days. Owner logs show energy 1 of 5 on 2 of the last 3 days.
Physical exam: Temperature 39.1 C, heart rate 96, mild tenderness when the back is pressed. Weight: 10.2 kg
Assessment: Likely muscle strain from rough play. No sign of fever or infection.
Plan: Rest and short lead walks for 7 days. Blood test sent to the lab. Recheck: 26 November 2026
Veterinarian: Dr Aisha Rahman
'''),
  DemoDocument('biscuit-blood-test.pdf', 'Blood test results', 'Biscuit', 'Lab report, all within range', '''
VetLab Diagnostics, Petaling Jaya
Lot 8, Jalan 51A/223, Petaling Jaya  |  lab@example-vetlab.my
LABORATORY REPORT - Haematology and Biochemistry
Patient name: Biscuit  Species: Canine  Requested by: Sunway Paws Veterinary Clinic
Specimen received: November 19, 2026
Test  Result  Reference range
WBC  9.1  5.5 - 16.9
RBC  7.2  5.5 - 8.5
Haematocrit  48%  37 - 55%
Creatinine  98  44 - 159
ALT  52  10 - 125
Glucose  5.4  3.9 - 7.9
Comments: All results within reference range. No sign of infection or organ trouble.
Clinician: Dr Priya Nair
'''),
  DemoDocument('biscuit-prescription.pdf', 'Prescription: pain relief', 'Biscuit', 'Medicines are picked out', '''
Sunway Paws Veterinary Clinic
12 Jalan PJS 11/15, Bandar Sunway, Selangor  |  03-5611 2040
PRESCRIPTION
Pet: Biscuit  Weight: 10.2 kg
Date: 2026-11-19
Meloxicam (Metacam) 1.5 mg/ml oral suspension
Give 0.7 ml by mouth once daily with food for 5 days
Gabapentin 100 mg capsule, twice daily for 5 days if still sore
Do not give with other pain medicines.
Dispensed by Dr Aisha Rahman
'''),
  // ---- Mochi, domestic shorthair: off her food ----
  DemoDocument('mochi-visit-appetite.pdf', 'Visit: eating less', 'Mochi', 'Complete visit summary with recheck', '''
Kelana Animal Hospital
3 Jalan SS7/19, Kelana Jaya, Petaling Jaya  |  03-7804 1188
CONSULTATION SUMMARY
Patient: Mochi  Species: Cat  Age: 6 years
Visit date: 18 November 2026
Reason for visit: Left dinner on 2 of the last 3 days. Hissing when the mouth is touched.
Physical exam: Temperature 38.7 C. Red gums and heavy tartar on the back teeth. Weight: 4.0 kg
Assessment: Dental disease making eating sore. Booked for a dental clean.
Plan: Soft food and appetite support until the dental. Recheck: 25 November 2026
Veterinarian: Dr Lim Wei Jie
'''),
  DemoDocument('mochi-prescription.pdf', 'Prescription: appetite support', 'Mochi', 'Medicines are picked out', '''
Kelana Animal Hospital
3 Jalan SS7/19, Kelana Jaya, Petaling Jaya  |  03-7804 1188
PRESCRIPTION
Pet: Mochi
Date: 2026-11-18
Mirtazapine transdermal ointment 2 mg
Apply a 1.5 inch line to the inside of the ear once daily for 7 days
Buprenorphine 0.3 mg/ml oral, 0.1 ml twice daily for 3 days
Wear gloves when applying.
Dispensed by Dr Lim Wei Jie
'''),
  DemoDocument('mochi-dental-procedure.pdf', 'Dental procedure report', 'Mochi', 'Surgery record', '''
Kelana Animal Hospital
3 Jalan SS7/19, Kelana Jaya, Petaling Jaya  |  03-7804 1188
SURGICAL AND ANAESTHETIC REPORT
Patient: Mochi  Species: Cat
Date of procedure: 22 November 2026
Procedure: Dental scale and polish under general anaesthetic. Two back teeth removed.
Anaesthetic: Uneventful. Recovered well, eating soft food the same evening.
Weight: 3.9 kg
Discharge notes: Soft food for 5 days. Pain relief as prescribed.
Follow-up: 06 December 2026
Surgeon: Dr Lim Wei Jie
'''),
  DemoDocument('mochi-vaccination.pdf', 'Vaccination certificate', 'Mochi', 'Complete, cat vaccines', '''
Kelana Animal Hospital
3 Jalan SS7/19, Kelana Jaya, Petaling Jaya  |  03-7804 1188
VACCINATION CERTIFICATE
Pet name: Mochi  Species: Cat  Breed: Domestic shorthair
Date of vaccination: 12/05/2026
Vaccine  Product  Batch
FVRCP  Felocell 3  FC4410
FeLV  Leucogen  LG2207
Weight: 4.2 kg
Next due: 12/05/2027
Attending vet: Dr Lim Wei Jie
'''),
  // ---- Pepper, Border Collie puppy: healthy ----
  DemoDocument('pepper-puppy-vaccinations.pdf', 'Puppy vaccination card', 'Pepper', 'Complete, next dose due', '''
Bangsar Vets
21 Jalan Telawi 3, Bangsar Baru, Kuala Lumpur  |  03-2282 7700
PUPPY VACCINATION RECORD
Pet name: Pepper  Species: Dog  Breed: Border Collie  Born: 14/07/2026
Date of vaccination: 06/11/2026
Vaccine  Dose  Batch
DHPP  2nd of 3  DH9120
Leptospirosis  2nd of 2  LP1102
Weight: 6.0 kg
Next due: 04/12/2026 (3rd puppy dose)
Attending vet: Dr Marcus Chong
'''),
  DemoDocument('pepper-parasite-prevention.pdf', 'Prescription: worms and fleas', 'Pepper', 'Medicines are picked out', '''
Bangsar Vets
21 Jalan Telawi 3, Bangsar Baru, Kuala Lumpur  |  03-2282 7700
PRESCRIPTION
Pet: Pepper  Weight: 6.0 kg
Date: 06 November 2026
Milbemax Puppy tablet, 1 tablet by mouth every month
NexGard Spectra chewable 3.6 - 7.5 kg, 1 chew every month
Next due: 06 December 2026
Dispensed by Dr Marcus Chong
'''),
  DemoDocument('pepper-microchip.pdf', 'Microchip registration', 'Pepper', 'Not a vet visit: MyPet asks for the type', '''
Malaysian Pet Microchip Registry
Registration confirmation
Animal: Pepper
Microchip number: 900 118 000 456 789
Implanted on: 06/11/2026
Keep this number safe. Update your phone number if you move.
'''),
  // ---- Bean, Ragdoll kitten: new, MyPet still learning ----
  DemoDocument('bean-first-check.pdf', 'First kitten check', 'Bean', 'No date or clinic: MyPet asks for them', '''
New kitten health check
Patient: Bean  Species: Cat  Age: 10 weeks
Reason for visit: First check after adoption.
Physical exam: Bright and playful. Clean ears, no fleas seen. Weight: 1.1 kg
Vaccines given: FVRCP 1st dose
Plan: 2nd vaccine dose in 3 to 4 weeks. Kitten food 4 times a day.
Veterinarian: Dr Nur Hidayah
'''),
  DemoDocument('bean-flea-treatment.pdf', 'Prescription: flea and worm', 'Bean', 'Medicines are picked out', '''
Happy Tails Vet
88 Jalan Kenari 5, Puchong  |  03-8070 5522
PRESCRIPTION
Pet: Bean
Date: 2026-11-17
Revolution Plus for kittens 1.25 - 2.5 kg
Apply 1 pipette on the back of the neck once a month
Next due: 2026-12-17
Dispensed by Dr Nur Hidayah
'''),
  // ---- Tricky ones, for any pet ----
  DemoDocument('scanned-vet-letter.pdf', 'Scanned vet letter', null, 'A photo of a page: MyPet says it cannot read it', '''
Sunway Paws Veterinary Clinic
Letter of visit
Patient: Biscuit
Visit date: 02 October 2026
Seen for a routine check. All well.
Dr Aisha Rahman
''', scanned: true),
  DemoDocument('luna-visit-other-pet.pdf', "Another pet's record", null, 'Names another pet: MyPet warns you', '''
Bangsar Vets
21 Jalan Telawi 3, Bangsar Baru, Kuala Lumpur  |  03-2282 7700
CONSULTATION SUMMARY
Patient: Luna  Species: Dog  Age: 3 years
Visit date: 10 November 2026
Reason for visit: Annual check and vaccinations.
Physical exam: Healthy. Weight: 22.4 kg
Assessment: Healthy adult dog.
Veterinarian: Dr Marcus Chong
'''),
];
