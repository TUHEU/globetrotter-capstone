import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// NOUVELLE FONCTIONNALITÉ 1 : Suggestions de voyage intelligentes
/// 
/// Utilise l'IA pour proposer des itinéraires personnalisés basés sur :
/// - Intérêts de l'utilisateur
/// - Durée disponible
/// - Budget
/// - Météo et saisons
/// - Attractions tendances
class AITripSuggestionsScreen extends StatefulWidget {
  const AITripSuggestionsScreen({Key? key}) : super(key: key);

  @override
  State<AITripSuggestionsScreen> createState() =>
      _AITripSuggestionsScreenState();
}

class _AITripSuggestionsScreenState extends State<AITripSuggestionsScreen> {
  bool _isLoading = false;
  String _selectedDuration = '1 jour';
  String _selectedBudget = 'Modéré';
  String _selectedInterest = 'Culture';
  List<AISuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _generateSuggestions();
  }

  Future<void> _generateSuggestions() async {
    setState(() => _isLoading = true);
    
    // Simuler l'appel API à l'IA pour générer les suggestions
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _suggestions = [
        AISuggestion(
          title: 'Yaoundé Culturelle',
          description:
              'Découvrez l\'histoire riche de Yaoundé en visitant les musées et sites historiques',
          places: ['Musée Nationale du Cameroun', 'Basilique Marie-Reine-des-Apôtres', 'Château Kingue'],
          duration: _selectedDuration,
          estimatedCost: '15,000 - 25,000 FCFA',
          rating: 4.8,
          matchScore: 95,
          icon: Icons.museum,
          color: const Color(0xFF1976D2),
        ),
        AISuggestion(
          title: 'Nature & Aventure',
          description: 'Randonnées et exploration des parcs naturels autour de Yaoundé',
          places: ['Parc de la Tête du Dragon', 'Forêts tropicales', 'Points de vue panoramiques'],
          duration: _selectedDuration,
          estimatedCost: '10,000 - 20,000 FCFA',
          rating: 4.6,
          matchScore: 88,
          icon: Icons.nature,
          color: const Color(0xFF388E3C),
        ),
        AISuggestion(
          title: 'Gastronomie & Vie Nocturne',
          description: 'Expérience culinaire et découverte de la vie nocturne à Yaoundé',
          places: ['Restaurants populaires', 'Bars traditionnels', 'Marchés de nuit'],
          duration: _selectedDuration,
          estimatedCost: '20,000 - 35,000 FCFA',
          rating: 4.5,
          matchScore: 82,
          icon: Icons.restaurant,
          color: const Color(0xFFD32F2F),
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggestions IA'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Filters section
            Container(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personnalisez vos préférences',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // Duration dropdown
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedDuration,
                    items: ['30 min', '1 jour', '2-3 jours', 'Week-end', 'Une semaine']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDuration = val);
                        _generateSuggestions();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Budget dropdown
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedBudget,
                    items: ['Économique', 'Modéré', 'Confortable', 'Luxe']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBudget = val);
                        _generateSuggestions();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Interest dropdown
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedInterest,
                    items: ['Culture', 'Nature', 'Gastronomie', 'Aventure', 'Shopping']
                        .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedInterest = val);
                        _generateSuggestions();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Suggestions list
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Génération des suggestions IA...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              )
            else if (_suggestions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune suggestion disponible',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return _AITripSuggestionCard(suggestion: suggestion);
                },
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class AISuggestion {
  final String title;
  final String description;
  final List<String> places;
  final String duration;
  final String estimatedCost;
  final double rating;
  final int matchScore;
  final IconData icon;
  final Color color;

  AISuggestion({
    required this.title,
    required this.description,
    required this.places,
    required this.duration,
    required this.estimatedCost,
    required this.rating,
    required this.matchScore,
    required this.icon,
    required this.color,
  });
}

class _AITripSuggestionCard extends StatelessWidget {
  final AISuggestion suggestion;

  const _AITripSuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          // Naviguer vers le détail de la suggestion
          _showSuggestionDetail(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and rating
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: suggestion.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      suggestion.icon,
                      color: suggestion.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${suggestion.rating}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Match score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: suggestion.matchScore > 90
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${suggestion.matchScore}% match',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: suggestion.matchScore > 90
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                suggestion.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        suggestion.duration,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        suggestion.estimatedCost,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Places preview
              Wrap(
                spacing: 8,
                children: suggestion.places
                    .take(3)
                    .map(
                      (place) => Chip(
                        label: Text(
                          place,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            suggestion.color.withValues(alpha: 0.15),
                        labelStyle: TextStyle(color: suggestion.color),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 12),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showSuggestionDetail(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: suggestion.color,
                  ),
                  child: const Text('Voir l\'itinéraire complet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuggestionDetail(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Détail: ${suggestion.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
