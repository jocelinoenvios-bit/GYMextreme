/// Um campo de circunferencia (em cm) da ficha de avaliacao fisica em
/// papel: chave usada no Firestore + rotulo mostrado no formulario.
class CircunferenciaField {
  const CircunferenciaField(this.key, this.label);

  final String key;
  final String label;
}

/// Mesma ordem e nomenclatura da ficha "GYM XTREME" em papel (secao
/// CIRCUNFERENCIAS), pra quem preenche reconhecer o formulario de cara.
const List<CircunferenciaField> circunferenciaFields = [
  CircunferenciaField('pescoco', 'Pescoço'),
  CircunferenciaField('ombro', 'Ombro'),
  CircunferenciaField('peito', 'Peito'),
  CircunferenciaField('bracoDRelaxado', 'Braço D. relaxado'),
  CircunferenciaField('bracoERelaxado', 'Braço E. relaxado'),
  CircunferenciaField('bracoDContraido', 'Braço D. contraído'),
  CircunferenciaField('bracoEContraido', 'Braço E. contraído'),
  CircunferenciaField('antebracoD', 'Antebraço D.'),
  CircunferenciaField('antebracoE', 'Antebraço E.'),
  CircunferenciaField('cintura', 'Cintura'),
  CircunferenciaField('abdomen', 'Abdômen'),
  CircunferenciaField('gluteo', 'Glúteo (quadril)'),
  CircunferenciaField('coxaProximalD', 'Coxa proximal D.'),
  CircunferenciaField('coxaProximalE', 'Coxa proximal E.'),
  CircunferenciaField('vastoLateralD', 'Vasto lateral D.'),
  CircunferenciaField('vastoLateralE', 'Vasto lateral E.'),
  CircunferenciaField('panturrilhaD', 'Panturrilha D.'),
  CircunferenciaField('panturrilhaE', 'Panturrilha E.'),
];
