# uber

Aplicativo clone do Uber

## Getting Started

Clone do Uber feito com Flutter.
Com ele o passageiro vai ser capaz de solicitar um Uber enquanto o motorista terá a visibilidade de todas as solicitações de corridas, podendo escolher qual corrida aceitar. Após aceitar uma corrida o motorista pode se deslocar até o local do passageiro, o mapa será constantemente atualizado com os marcadores tanto de passageiro como de motorista, para que ambos saibam onde estão. Ao chegar, o motorista pode iniciar a corrida com o passageiro, e nesse caso é exibido no mapa, o marcador com o local do destino da corrida.
Quando o motorista levar o passageiro para seu local de destino, ele pode finalizar a corrida, o calculo da corrida será feito, com base no local que o passageiro solicitou o uber e no destino solicitado. Após a confirmação de que a corrida foi concluida o ciclo dessa solicitação é encerrado e o passageiro pode solicitar um novo Uber e o motorista poderá aceitar uma nova corrida.

Plugins utilizados:
  cupertino_icons: ^0.1.2
  google_maps_flutter: ^0.5.26+4
  geolocator: ^5.3.1
  firebase: ^7.3.0
  cloud_firestore: ^0.13.5
  firebase_auth: ^0.16.0
  intl: ^0.16.1
Nesse aplicativo é utilizado a API de mapas da Google.



A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
