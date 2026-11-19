// Made-up vet documents in four common layouts, used to test the PDF import.
// No real pet or clinic. tool/make_sample_vet_pdfs.dart turns them into PDFs.
const vetSamples = <String, String>{
  'vaccination-certificate': '''
Sunway Paws Veterinary Clinic
12 Jalan PJS 11/15, Bandar Sunway, Selangor
VACCINATION CERTIFICATE
Pet name: Biscuit   Species: Dog   Breed: Shiba Inu
Owner: E. Soo
Date of vaccination: 03/11/2026
Vaccine            Manufacturer    Lot No
Rabies (Nobivac)   MSD             RB2291
DHPPi              MSD             DH8812
Leptospirosis L4   MSD             LP0921
Weight: 9.8 kg
Next due: 03/11/2027
Attending vet: Dr Aisha Rahman
''',
  'visit-summary': '''
Kelana Animal Hospital
Consultation summary
Patient: Mao  Species: Cat  Age: 4 years
Visit date: 14 October 2026
Reason for visit: Eating less for three days
Physical exam: Temperature 38.6 C, heart rate 180. Weight: 4.1 kg
Assessment: Mild dental tartar. Otherwise healthy.
Plan: Dental check in two weeks. Recheck: 28 October 2026
Veterinarian: Dr Lim Wei Jie
''',
  'prescription': '''
Happy Tails Vet
PRESCRIPTION
Pet: Woof
Date: 2026-09-21
Meloxicam (Metacam) 1.5 mg/ml oral suspension
Give 0.3 ml by mouth once daily with food for 5 days
Amoxicillin 50 mg tablet, twice daily for 7 days
Dispensed by Dr. Grace Tan
''',
  'lab-report': '''
VetLab Diagnostics, Petaling Jaya
LABORATORY REPORT - Haematology and Biochemistry
Patient name: Mochi
Specimen received: September 2, 2026
Test        Result    Reference range
WBC         8.2       5.5 - 19.5
RBC         7.9       5.0 - 10.0
Creatinine  140       71 - 212
ALT         45        12 - 130
Comments: All results within reference range.
Clinician: Dr Priya Nair
''',
};
