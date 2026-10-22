# SPDX-License-Identifier: Apache-2.0 OR MIT
import json,pathlib,tempfile,unittest
from build_lexicons import compile_rows,normalize,score

class ImporterTests(unittest.TestCase):
    def test_regional_profiles_do_not_mix(self):
        self.assertIsNone(score({'ipa':'/kaˈfe/','tags':['Spain']},'es-AR'))
        self.assertIsNone(score({'ipa':'/kaˈfe/','tags':['Argentina']},'es'))
        self.assertIsNone(score({'ipa':'/kaˈfe/','tags':['Mexico']},'es-AR'))
        self.assertIsNone(score({'ipa':'/kaˈfe/','tags':['Portugal']},'pt-BR'))
        self.assertIsNone(score({'ipa':'/kafe/','tags':['Quebec']},'fr'))
        self.assertIsNone(score({'ipa':'/kaˈfe/','tags':['Classical-Sanskrit']},'hi'))
    def test_missing_stress_is_not_invented(self):
        self.assertIsNone(normalize('/telefono/','it'))
        self.assertEqual(normalize('/teˈlɛfono/','it'),'teˈlɛfono')
    def test_different_profiles_and_literal_sounds(self):
        self.assertEqual(normalize('/ˈʝu.bja/','es-AR'),'ˈʃubja')
        self.assertEqual(normalize('/ˈʝu.bja/','es'),'ˈʝubja')
        self.assertEqual(normalize('/ˈθe.na/','es-419'),'ˈsena')
        self.assertIsNone(normalize('/ˈkəɾɫ/','es'))
    def test_syllable_boundaries_are_not_false_affricates(self):
        self.assertEqual(normalize('/ˈat.sa/','it'),'ˈatsa')
        self.assertEqual(normalize('/aˈt͡sa/','it'),'aˈʦa')
    def test_ambiguity_and_case_are_preserved(self):
        records=[{'word':'ancora','pos':'noun','sounds':[{'ipa':'/ˈankora/'},{'ipa':'/anˈkora/'}]},
                 {'word':'Rosa','pos':'name','sounds':[{'ipa':'/ˈrɔza/'}]},
                 {'word':'telefono','pos':'noun','sounds':[{'ipa':'/teˈlɛfono/'}]}]
        with tempfile.TemporaryDirectory() as tmp:
            p=pathlib.Path(tmp)/'source.jsonl';p.write_text(''.join(json.dumps(r)+'\n' for r in records))
            entries,counts,_=compile_rows('it',p)
        self.assertNotIn('ancora',entries)
        self.assertIn('Rosa',entries);self.assertNotIn('rosa',entries)
        self.assertEqual(counts['ambiguous_keys_excluded'],1)

if __name__=='__main__':unittest.main()
