// NFR06 and FR-N04: Firestore security rules tests (report Table 3.2).
// Run: npm install && npm test   (needs Java for the Firestore emulator)
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, updateDoc, collection, query, where, getDocs } from 'firebase/firestore';

let env;

const pet = (carers) => ({
  name: 'Milo',
  species: 'dog',
  breed: '',
  status: 'active',
  carerIds: carers,
  createdAt: '2027-03-01T00:00:00Z',
});

const entry = (by, extra = {}) => ({
  petId: 'p1',
  kind: 'dailyLog',
  day: '2027-03-02',
  createdAt: '2027-03-02T10:00:00Z',
  createdBy: by,
  supersedes: null,
  voided: false,
  data: { ate: true, energy: 4, toiletingNormal: true },
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mypet',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'pets/p1'), pet(['alice']));
    await setDoc(doc(db, 'pets/p1/entries/e1'), entry('alice'));
  });
});

after(async () => env.cleanup());

const as = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

test('NFR06-1 a carer can read their pet and its entries', async () => {
  await assertSucceeds(getDoc(doc(as('alice'), 'pets/p1')));
  await assertSucceeds(getDoc(doc(as('alice'), 'pets/p1/entries/e1')));
  await assertSucceeds(getDocs(query(collection(as('alice'), 'pets'), where('carerIds', 'array-contains', 'alice'))));
});

test('NFR06-2 someone who is not a carer cannot read the pet or its entries', async () => {
  await assertFails(getDoc(doc(as('mallory'), 'pets/p1')));
  await assertFails(getDoc(doc(as('mallory'), 'pets/p1/entries/e1')));
  await assertFails(getDocs(collection(as('mallory'), 'pets')));
});

test('NFR06-3 signed-out devices cannot read anything', async () => {
  await assertFails(getDoc(doc(as(null), 'pets/p1')));
  await assertFails(getDoc(doc(as(null), 'pets/p1/entries/e1')));
});

test('NFR06-4 nobody can add themselves as a carer or write to another pet', async () => {
  await assertFails(updateDoc(doc(as('mallory'), 'pets/p1'), { carerIds: ['alice', 'mallory'] }));
  await assertFails(setDoc(doc(as('mallory'), 'pets/p1/entries/x'), entry('mallory')));
  await assertFails(setDoc(doc(as('mallory'), 'pets/p2'), pet(['alice'])));
});

test('a carer can create a pet and add a log', async () => {
  await assertSucceeds(setDoc(doc(as('bob'), 'pets/p2'), pet(['bob'])));
  await assertSucceeds(setDoc(doc(as('alice'), 'pets/p1/entries/e2'), entry('alice')));
});

test('a pet must be a cat or a dog (FR01)', async () => {
  await assertFails(setDoc(doc(as('bob'), 'pets/p3'), { ...pet(['bob']), species: 'rabbit' }));
});

test('a log must be written as the signed-in carer', async () => {
  await assertFails(setDoc(doc(as('alice'), 'pets/p1/entries/e3'), entry('bob')));
});

test('FRN04-1 entries cannot be changed or deleted, only replaced by a new entry', async () => {
  await assertFails(updateDoc(doc(as('alice'), 'pets/p1/entries/e1'), { 'data.energy': 1 }));
  await assertFails(setDoc(doc(as('alice'), 'pets/p1/entries/e1'), entry('alice', { voided: true })));
  await assertFails(deleteDoc(doc(as('alice'), 'pets/p1/entries/e1')));
  await assertSucceeds(setDoc(doc(as('alice'), 'pets/p1/entries/e1v2'), entry('alice', { supersedes: 'e1' })));
});

test('pets are archived, never deleted (FR01)', async () => {
  await assertFails(deleteDoc(doc(as('alice'), 'pets/p1')));
  await assertSucceeds(updateDoc(doc(as('alice'), 'pets/p1'), { status: 'archived' }));
});

test('FRN02 a behaviour result cannot carry the audio', async () => {
  await assertFails(setDoc(doc(as('alice'), 'pets/p1/entries/b1'),
    entry('alice', { kind: 'behaviourResult', data: { topLabel: 'likely calm', audio: 'AAAA' } })));
  await assertSucceeds(setDoc(doc(as('alice'), 'pets/p1/entries/b2'),
    entry('alice', { kind: 'behaviourResult', data: { topLabel: 'likely calm', likelihoods: { 'likely calm': 0.6 } } })));
});
