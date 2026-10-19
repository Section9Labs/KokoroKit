# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Original, purpose-written listening passages. No external book text."""
import json
from pathlib import Path
texts = {
'en': {
'prose': 'The house was quiet when Eleanor returned. Beyond the window, rain softened the outline of the hills. She put the unopened letter beside the lamp and waited. Somewhere upstairs, a floorboard creaked. This time, she was certain that she had heard it.',
'dialogue': '“You knew?” Daniel asked. “All this time, you knew?” Eleanor looked away. “I suspected. That is not the same thing.” For a moment, neither of them spoke. Then he lowered his voice. “Tell me what happened. Start at the beginning.”',
'numbers': 'Chapter XII. At 12:30, Dr. Martin opened the ledger. The first entry was dated March 14, 1923. Twelve pounds and fifty pence had disappeared. “Only twelve?” she asked. There were three more pages. By the time she reached the last one, her hands were trembling.'},
'es': {
'prose': 'La casa estaba en silencio cuando Elena regresó. Tras la ventana, la lluvia borraba el contorno de las colinas. Dejó la carta sin abrir junto a la lámpara y esperó. En el piso de arriba, una tabla crujió. Esta vez estaba segura de haberlo oído.',
'dialogue': '—¿Lo sabías? —preguntó Daniel—. ¿Lo sabías desde el principio? Elena apartó la mirada. —Lo sospechaba. No es lo mismo. Durante un momento, ninguno habló. Entonces él bajó la voz. —Cuéntame qué pasó. Empieza por el principio.',
'numbers': 'Capítulo XII. A las 12:30, la doctora Martín abrió el registro. La primera entrada era del 14 de marzo de 1923. Faltaban 12,50 euros. —¿Solo doce? —preguntó. Quedaban tres páginas. Cuando llegó a la última, le temblaban las manos.'}}
cases=[]
for language, passages in texts.items():
    for voice in (['af_heart','af_bella'] if language=='en' else ['ef_dora','em_alex']):
        for category,text in passages.items():
            cases.append(dict(key=f'{language}-{voice}-{category}',language=language,voice=voice,category=category,text=text))
    cases.append(dict(key=f'{language}-continuity',language=language,voice='af_heart' if language=='en' else 'ef_dora',category='continuity',text='\n\n'.join(passages.values())))
Path(__file__).with_name('corpus.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
