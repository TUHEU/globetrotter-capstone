import 'package:flutter/material.dart';

/// NOUVELLE FONCTIONNALITÉ 2 : Calculateur de coûts de voyage en temps réel
/// 
/// Calcule automatiquement les coûts totaux d'un voyage incluant :
/// - Transport (taxi, bus, moto-taxi)
/// - Hébergement
/// - Restauration
/// - Activités et attractions
/// - Budget imprévu
class TravelCostsCalculatorScreen extends StatefulWidget {
  const TravelCostsCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<TravelCostsCalculatorScreen> createState() =>
      _TravelCostsCalculatorScreenState();
}

class _TravelCostsCalculatorScreenState extends State<TravelCostsCalculatorScreen> {
  final TextEditingController _transportController = TextEditingController(text: '5000');
  final TextEditingController _accommodationController =
      TextEditingController(text: '20000');
  final TextEditingController _foodController = TextEditingController(text: '10000');
  final TextEditingController _activitiesController = TextEditingController(text: '8000');
  final TextEditingController _miscController = TextEditingController(text: '2000');
  final TextEditingController _daysController = TextEditingController(text: '1');

  int _numberOfPeople = 1;
  bool _splitCosts = false;

  @override
  void dispose() {
    _transportController.dispose();
    _accommodationController.dispose();
    _foodController.dispose();
    _activitiesController.dispose();
    _miscController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  double _parseAmount(String text) {
    return double.tryParse(text.replaceAll(' ', '')) ?? 0.0;
  }

  double get _totalTransport => _parseAmount(_transportController.text);
  double get _totalAccommodation => _parseAmount(_accommodationController.text);
  double get _totalFood => _parseAmount(_foodController.text);
  double get _totalActivities => _parseAmount(_activitiesController.text);
  double get _totalMisc => _parseAmount(_miscController.text);
  int get _days => int.tryParse(_daysController.text) ?? 1;

  double get _subtotal =>
      (_totalTransport + _totalAccommodation + _totalFood + _totalActivities + _totalMisc) *
      _days;

  double get _perPersonCost => _splitCosts ? _subtotal / _numberOfPeople : _subtotal;

  double get _averagePerDay => _subtotal / _days;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculateur de Coûts'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Summary card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coût Total du Voyage',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_subtotal.toStringAsFixed(0)} FCFA',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CostSummaryItem(
                        label: 'Par jour',
                        value: '${_averagePerDay.toStringAsFixed(0)} F',
                        icon: Icons.calendar_today,
                      ),
                      _CostSummaryItem(
                        label: 'Par personne',
                        value: '${_perPersonCost.toStringAsFixed(0)} F',
                        icon: Icons.person,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Number of people and split costs option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partage des frais',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nombre de personnes',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => setState(() {
                                        if (_numberOfPeople > 1) _numberOfPeople--;
                                      }),
                                      icon: const Icon(Icons.remove),
                                      constraints: const BoxConstraints.tightFor(
                                        width: 40,
                                        height: 40,
                                      ),
                                    ),
                                    Text(
                                      _numberOfPeople.toString(),
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    IconButton(
                                      onPressed: () => setState(() {
                                        if (_numberOfPeople < 20) _numberOfPeople++;
                                      }),
                                      icon: const Icon(Icons.add),
                                      constraints: const BoxConstraints.tightFor(
                                        width: 40,
                                        height: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Diviser les coûts',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              value: _splitCosts,
                              onChanged: (val) =>
                                  setState(() => _splitCosts = val ?? false),
                              activeColor: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cost breakdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Durée du voyage',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nombre de jours',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cost input fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Détail des dépenses',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _CostInputField(
                        label: 'Transport',
                        icon: Icons.directions_car,
                        controller: _transportController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _CostInputField(
                        label: 'Hébergement',
                        icon: Icons.hotel,
                        controller: _accommodationController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _CostInputField(
                        label: 'Restauration',
                        icon: Icons.restaurant,
                        controller: _foodController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _CostInputField(
                        label: 'Activités',
                        icon: Icons.attractions,
                        controller: _activitiesController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _CostInputField(
                        label: 'Divers (imprévus)',
                        icon: Icons.miscellaneous_services,
                        controller: _miscController,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Budget visualization
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Répartition du budget',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _BudgetBreakdownItem(
                        label: 'Transport',
                        amount: _totalTransport * _days,
                        total: _subtotal,
                        color: const Color(0xFF1976D2),
                      ),
                      const SizedBox(height: 12),
                      _BudgetBreakdownItem(
                        label: 'Hébergement',
                        amount: _totalAccommodation * _days,
                        total: _subtotal,
                        color: const Color(0xFFF57C00),
                      ),
                      const SizedBox(height: 12),
                      _BudgetBreakdownItem(
                        label: 'Restauration',
                        amount: _totalFood * _days,
                        total: _subtotal,
                        color: const Color(0xFF388E3C),
                      ),
                      const SizedBox(height: 12),
                      _BudgetBreakdownItem(
                        label: 'Activités',
                        amount: _totalActivities * _days,
                        total: _subtotal,
                        color: const Color(0xFF7B1FA2),
                      ),
                      const SizedBox(height: 12),
                      _BudgetBreakdownItem(
                        label: 'Divers',
                        amount: _totalMisc * _days,
                        total: _subtotal,
                        color: const Color(0xFFC62828),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _transportController.text = '0';
                        _accommodationController.text = '0';
                        _foodController.text = '0';
                        _activitiesController.text = '0';
                        _miscController.text = '0';
                        _daysController.text = '1';
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Budget sauvegardé: ${_subtotal.toStringAsFixed(0)} FCFA',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CostSummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CostSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CostInputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _CostInputField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: 'FCFA',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _BudgetBreakdownItem extends StatelessWidget {
  final String label;
  final double amount;
  final double total;
  final Color color;

  const _BudgetBreakdownItem({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (amount / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(0)} FCFA',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}
