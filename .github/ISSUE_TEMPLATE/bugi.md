---
name: Bugi
about: Ilmoita järjestelmässä havaitusta bugista.
title: "[BUG]"
labels: 'bug'
assignees: ''
body:
  - type: markdown
    attributes:
      value: 
**Kuvaus**
Selkeä kuvaus siitä mitä teit, missä teit ja mitä tapahtui.

**Kuinka saadaan toistettua**
Kirjoita vaiheet:
1. Mene '...'
2. Paina '....'
3. Selaa '....'
4. Virhe

**Kuvakaappaus**
Jos mahdollista, niin kuvakaappaus tapahtumasta.

**Järjestelmä (täytä seuraavat kohdat):**
 - Kimppa [mm. OUTI]
 - Selain [mm. chrome, safari]

**Muuta lisättävää**
Lisää jotain muuta bugiin liittyen.
  - type: dropdown
    id: kimppa
    attributes:
      label: Missä kimpassa ongelma esiintyy
      multiple: true
      options:
        - Kaikki
        - Lappi
        - OUTI
        - Vaski

---

