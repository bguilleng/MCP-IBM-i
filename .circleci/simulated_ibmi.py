#!/usr/bin/env python3
"""Synthetic fixtures only, never actual IBM i qualification."""
import argparse,os,json,unittest
from pathlib import Path
from decimal import Decimal
from xml.etree.ElementTree import Element,SubElement,ElementTree
a=argparse.ArgumentParser();a.add_argument('--project',required=True);a.add_argument('--out',required=True);p=a.parse_args()
class Cases(unittest.TestCase):
 def test_ccsid37(self):self.assertEqual('IBMI'.encode('cp037').decode('cp037'),'IBMI')
 def test_source_width(self):self.assertEqual(len('X'.ljust(100)),100)
 def test_decimal(self):self.assertEqual(Decimal('10.10')-Decimal('0.10'),Decimal('10.00'))
 def test_fail_closed(self):self.assertFalse({'certified':False}['certified'])
 def test_domain(self):self.assertEqual({'A':['B']}['A'],['B'])
r=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Cases))
d=Path(p.out);d.mkdir(parents=True,exist_ok=True)
root=Element('testsuite',name='ibmi.synthetic.'+p.project,tests=str(r.testsRun),errors=str(len(r.errors)),failures=str(len(r.failures)))
for t in ['ccsid37','source_width','decimal','fail_closed','domain']:SubElement(root,'testcase',classname='ibmi.simulated',name='test_'+t)
ElementTree(root).write(d/'junit-simulated.xml',encoding='utf-8',xml_declaration=True)
(d/'simulated-evidence.json').write_text(json.dumps(dict(project=p.project,execution_class='SIMULATED',native_ibmi_executed=False,certified=False,commit=os.getenv('CIRCLE_SHA1','LOCAL'),tests=r.testsRun,errors=len(r.errors),failures=len(r.failures)),indent=2)+'\n')
raise SystemExit(not r.wasSuccessful())
