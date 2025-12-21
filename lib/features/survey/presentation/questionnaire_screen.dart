import 'package:flutter/material.dart';
import '../data/models/survey_response_dto.dart';
import '../data/survey_repository.dart';
import '../../auth/data/auth_service.dart';

/// Questionnaire screen for running preferences
class QuestionnaireScreen extends StatefulWidget {
  final SurveyResponseDto? existingResponse;
  final VoidCallback? onComplete;
  final bool isModal;

  const QuestionnaireScreen({
    super.key,
    this.existingResponse,
    this.onComplete,
    this.isModal = true,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final SurveyRepository _repository = SurveyRepository.instance;
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _isSaving = false;

  // Form values
  final Set<String> _preferredDays = {};
  final Set<String> _timeOfDay = {};
  String? _experienceLevel;
  String? _activityType;
  String? _intensityPreference;
  String? _socialVibe;
  String? _motivationType;
  String? _coachingStyle;
  String? _musicPreference;
  bool? _matchGenderPreference;

  @override
  void initState() {
    super.initState();
    _loadExistingResponse();
  }

  void _loadExistingResponse() {
    final existing = widget.existingResponse;
    if (existing != null) {
      setState(() {
        _preferredDays.addAll(existing.preferredDaysList);
        _timeOfDay.addAll(existing.timeOfDayList);
        _experienceLevel = existing.experienceLevel;
        _activityType = existing.activityType;
        _intensityPreference = existing.intensityPreference;
        _socialVibe = existing.socialVibe;
        _motivationType = existing.motivationType;
        _coachingStyle = existing.coachingStyle;
        _musicPreference = existing.musicPreference;
        _matchGenderPreference = existing.matchGenderPreference;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isCurrentPageComplete {
    switch (_currentPage) {
      case 0: // Schedule
        return _preferredDays.isNotEmpty && _timeOfDay.isNotEmpty;
      case 1: // Athletic profile
        return _experienceLevel != null &&
            _activityType != null &&
            _intensityPreference != null;
      case 2: // Social
        return _socialVibe != null &&
            _motivationType != null &&
            _coachingStyle != null &&
            _musicPreference != null;
      case 3: // Safety
        return _matchGenderPreference != null;
      default:
        return false;
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveSurvey();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveSurvey() async {
    final accessToken = _authService.accessToken;
    final currentUser = _authService.currentUser;
    if (accessToken == null || currentUser == null) {
      _showError('Please log in to save your preferences');
      return;
    }

    setState(() => _isSaving = true);

    final response = SurveyResponseDto(
      id: widget.existingResponse?.id,
      userId: currentUser.userId,
      preferredDays: _preferredDays.join(','),
      timeOfDay: _timeOfDay.join(','),
      experienceLevel: _experienceLevel,
      activityType: _activityType,
      intensityPreference: _intensityPreference,
      socialVibe: _socialVibe,
      motivationType: _motivationType,
      coachingStyle: _coachingStyle,
      musicPreference: _musicPreference,
      matchGenderPreference: _matchGenderPreference,
    );

    final result = await _repository.saveSurveyResponse(
      response,
      accessToken: accessToken,
    );

    setState(() => _isSaving = false);

    if (result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully!'),
            backgroundColor: Color(0xFF7ED321),
          ),
        );

        widget.onComplete?.call();

        if (widget.isModal) {
          Navigator.of(context).pop(true);
        }
      }
    } else {
      _showError(result.message ?? 'Failed to save preferences');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: const Text(
          'Running Preferences',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildSchedulePage(),
                _buildAthleticPage(),
                _buildSocialPage(),
                _buildSafetyPage(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(4, (index) {
              final isCompleted = index < _currentPage;
              final isCurrent = index == _currentPage;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? const Color(0xFF7ED321)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getPageTitle(_currentPage),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7ED321),
                ),
              ),
              Text(
                '${_currentPage + 1}/4',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle(int page) {
    switch (page) {
      case 0:
        return 'Schedule';
      case 1:
        return 'Athletic Profile';
      case 2:
        return 'Social Style';
      case 3:
        return 'Preferences';
      default:
        return '';
    }
  }

  Widget _buildSchedulePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Which days do you usually run?'),
          _buildSubtitle('Select all that apply'),
          const SizedBox(height: 16),
          _buildDaySelector(),
          const SizedBox(height: 32),
          _buildSectionTitle('Preferred running time?'),
          _buildSubtitle('Select all that apply'),
          const SizedBox(height: 16),
          _buildTimeSelector(),
        ],
      ),
    );
  }

  Widget _buildAthleticPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Your running level?'),
          const SizedBox(height: 16),
          _buildSingleSelectOptions(
            options: ExperienceLevel.all,
            selectedValue: _experienceLevel,
            displayName: ExperienceLevel.displayName,
            onSelect: (value) => setState(() => _experienceLevel = value),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Your primary focus?'),
          const SizedBox(height: 16),
          _buildSingleSelectOptions(
            options: ActivityType.all,
            selectedValue: _activityType,
            displayName: ActivityType.displayName,
            onSelect: (value) => setState(() => _activityType = value),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Intensity preference?'),
          const SizedBox(height: 16),
          _buildSingleSelectOptions(
            options: IntensityPreference.all,
            selectedValue: _intensityPreference,
            displayName: IntensityPreference.displayName,
            onSelect: (value) => setState(() => _intensityPreference = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Your social style?'),
          const SizedBox(height: 16),
          _buildSingleSelectOptionsWithDescription(
            options: SocialVibe.all,
            selectedValue: _socialVibe,
            displayName: SocialVibe.displayName,
            description: SocialVibe.description,
            onSelect: (value) => setState(() => _socialVibe = value),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Why do you run?'),
          const SizedBox(height: 16),
          _buildSingleSelectOptions(
            options: MotivationType.all,
            selectedValue: _motivationType,
            displayName: MotivationType.displayName,
            onSelect: (value) => setState(() => _motivationType = value),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Your coaching style?'),
          const SizedBox(height: 16),
          _buildSingleSelectOptionsWithDescription(
            options: CoachingStyle.all,
            selectedValue: _coachingStyle,
            displayName: CoachingStyle.displayName,
            description: CoachingStyle.description,
            onSelect: (value) => setState(() => _coachingStyle = value),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Music preference?'),
          const SizedBox(height: 16),
          _buildSingleSelectOptions(
            options: MusicPreference.all,
            selectedValue: _musicPreference,
            displayName: MusicPreference.displayName,
            onSelect: (value) => setState(() => _musicPreference = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 48, color: Color(0xFF7ED321)),
          const SizedBox(height: 16),
          _buildSectionTitle('Safety & Preferences'),
          _buildSubtitle('Your comfort matters to us'),
          const SizedBox(height: 32),
          _buildSectionTitle('Match with same gender only?'),
          const SizedBox(height: 16),
          _buildBooleanSelector(
            value: _matchGenderPreference,
            onSelect: (value) => setState(() => _matchGenderPreference = value),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can change these preferences anytime in Settings.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSubtitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PreferredDay.all.map((day) {
        final isSelected = _preferredDays.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _preferredDays.remove(day);
              } else {
                _preferredDays.add(day);
              }
            });
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF7ED321) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF7ED321) : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                PreferredDay.displayName(day),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      children: TimeOfDayPreference.all.map((time) {
        final isSelected = _timeOfDay.contains(time);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _timeOfDay.remove(time);
                } else {
                  _timeOfDay.add(time);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF7ED321).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7ED321)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFF7ED321)
                          : Colors.grey[200],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TimeOfDayPreference.label(time),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF7ED321)
                                : Colors.black87,
                          ),
                        ),
                        Text(
                          TimeOfDayPreference.displayName(time),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleSelectOptions({
    required List<String> options,
    required String? selectedValue,
    required String Function(String) displayName,
    required void Function(String) onSelect,
  }) {
    return Column(
      children: options.map((option) {
        final isSelected = selectedValue == option;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => onSelect(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF7ED321).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7ED321)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7ED321)
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: isSelected
                          ? const Color(0xFF7ED321)
                          : Colors.white,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    displayName(option),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF7ED321)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleSelectOptionsWithDescription({
    required List<String> options,
    required String? selectedValue,
    required String Function(String) displayName,
    required String Function(String) description,
    required void Function(String) onSelect,
  }) {
    return Column(
      children: options.map((option) {
        final isSelected = selectedValue == option;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => onSelect(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF7ED321).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7ED321)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7ED321)
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: isSelected
                          ? const Color(0xFF7ED321)
                          : Colors.white,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName(option),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF7ED321)
                                : Colors.black87,
                          ),
                        ),
                        if (description(option).isNotEmpty)
                          Text(
                            description(option),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBooleanSelector({
    required bool? value,
    required void Function(bool) onSelect,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onSelect(true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: value == true
                    ? const Color(0xFF7ED321).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: value == true
                      ? const Color(0xFF7ED321)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 32,
                    color: value == true
                        ? const Color(0xFF7ED321)
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: value == true
                          ? const Color(0xFF7ED321)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => onSelect(false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: value == false
                    ? const Color(0xFF7ED321).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: value == false
                      ? const Color(0xFF7ED321)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.people,
                    size: 32,
                    color: value == false
                        ? const Color(0xFF7ED321)
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No preference',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: value == false
                          ? const Color(0xFF7ED321)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentPage > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 16),
            Expanded(
              flex: _currentPage == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _isCurrentPageComplete && !_isSaving
                    ? _nextPage
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED321),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _currentPage == 3 ? 'Save Preferences' : 'Continue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
