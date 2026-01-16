import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  final String rules = """
Правила игры (черновая версия)

Добро пожаловать в авиасимулятор!

Здесь вы можете испытать себя в роли пилота, управляя различными типами воздушных судов. Цель игры — безопасно выполнять полёты, следуя маршрутам, указаниям диспетчеров и условиям миссий.

Основные правила:

Соблюдайте указания управления полётами и ограничения по высоте, скорости и маршруту.

Следите за состоянием самолёта и уровнем топлива.

Избегайте столкновений с другими объектами и нарушений воздушного пространства.

Успешная посадка завершает миссию и приносит очки опыта пилоту.

Нарушения или аварии снижают рейтинг и могут привести к завершению полёта.

Раздел находится в разработке. Подробные правила, классификация миссий и рейтинговая система будут добавлены в последующих обновлениях.
  """;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Правила игры")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              SizedBox(height: 32,),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rules,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
