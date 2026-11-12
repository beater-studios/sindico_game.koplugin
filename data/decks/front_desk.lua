return {
    {
        id = "kleber_swapped_package",
        char = "kleber",
        text = "Entreguei a encomenda do 501 para o 105 e a do 105 para o 501. Um recebeu um liquidificador. O outro recebeu algo que eu prefiro não descrever. Eu vi. Não devia ter aberto.",
        left = {
            label = "Pedir desculpas",
            result = "Ele foi até os dois e explicou tudo. Em detalhes. Em voz alta.",
            effects = { residents = -6, patience = -2, funds = 3 },
        },
        right = {
            label = "Armário de encomendas",
            result = "Armário comprado. Ele agora entrega a senha errada, com sinceridade.",
            effects = { funds = -6, residents = 9, patience = 1 },
            minutes = "Comprou armário de encomendas.",
        },
    },
    {
        id = "kleber_honest_visitor",
        char = "kleber",
        text = "A irmã do 1001 perguntou se ele estava em casa. Falei que ele estava, sim, mas que tinha pedido para eu dizer que não. Era para ser mentira, né? Ninguém me falou.",
        left = {
            label = "Treinar o Kleber",
            result = "Treinou. Agora ele diz: 'fui treinado para dizer que ele não está'.",
            effects = { patience = -6, residents = 5 },
        },
        right = {
            label = "Elogiar a honestidade",
            result = "O 1001 foi tirar satisfação com o Kleber, que foi honesto de novo.",
            effects = { residents = -5, patience = 4 },
        },
    },
    {
        id = "kleber_lost_package",
        char = "kleber",
        text = "Sumiu a encomenda do 1204. Câmera mostra um homem de boné levando, às 14h. O homem de boné sou eu. Eu não lembro, mas eu admito. Só não sei onde pus.",
        left = {
            label = "Ressarcir",
            result = "Era um anel de luz da Jéssica. Ela fez um vídeo sobre a dor da perda, e cresceu.",
            effects = { funds = -5, residents = 6 },
            minutes = "Ressarciu encomenda extraviada pelo porteiro, que confessou.",
        },
        right = {
            label = "Procurar antes",
            result = "Estava no lixo. Junto com uma pasta sua, que você procurava desde março.",
            effects = { patience = -7, residents = 3, building = 1 },
        },
    },
    {
        id = "kleber_sick_note",
        char = "kleber",
        text = "Trouxe um atestado para o senhor. Foi meu primo que fez, ele sabe imitar a letra. Mas eu preciso folgar porque quero, não por doença. Melhor o senhor saber.",
        left = {
            label = "Dar a folga",
            result = "Folgou. O substituto deixou entrar um vendedor de consórcio no 8º.",
            effects = { residents = -3, funds = -1, patience = 5 },
        },
        right = {
            label = "Sem folga",
            result = "Ele ficou. Avisou a todos que não queria estar ali, com muita educação.",
            effects = { residents = -4, patience = -4, funds = 3 },
        },
    },
    {
        id = "kleber_unnamed_visitor",
        char = "kleber",
        text = "Tem um homem aqui dizendo que é do gás. Perguntei se é mesmo. Ele disse que sim. Mas está sem crachá, sem uniforme, sem ferramenta e sem gás. Deixo subir?",
        left = {
            label = "Deixar subir",
            result = "Ele leu o medidor do 8º e foi embora. Era mesmo do gás. Ninguém acredita.",
            effects = { residents = -4, building = 4, patience = 1 },
        },
        right = {
            label = "Barrar",
            result = "Era do gás. O corte será na quinta, com R$ 180 de religação.",
            effects = { funds = -7, residents = 5 },
        },
    },
    {
        id = "kleber_tip_box",
        char = "kleber",
        text = "Na caixinha de fim de ano, o pessoal perguntou o que eu acho do senhor. Falei a verdade. Rendeu pouco para mim e nada para o senhor. Queria avisar antes da virada do ano.",
        left = {
            label = "Aumentar a caixinha",
            result = "Ele agradeceu e disse que você ainda não é bom, só é generoso.",
            effects = { funds = -4, residents = 8 },
        },
        right = {
            label = "Conversar a sério",
            result = "Depois da conversa, ele subiu sua nota de 4 para 6. É um progresso.",
            effects = { patience = -6, residents = 3, funds = 3 },
        },
    },
    {
        id = "kleber_logbook",
        char = "kleber",
        text = "Estou escrevendo tudo no livro de ocorrências, como o senhor pediu. 'O síndico chegou às 11h e parecia ter dormido mal.' Dona Neide pediu para ler. Mostro?",
        left = {
            label = "Mostrar",
            result = "Ela leu tudo, e pediu cópia. Agora você é lido em voz alta no 3º.",
            effects = { residents = 5, patience = -6 },
        },
        right = {
            label = "Livro é sigiloso",
            result = "Sigiloso? Em uma hora, todos no prédio queriam saber o que há nele.",
            effects = { residents = -5, patience = 4 },
        },
    },
    {
        id = "pri_ladder_701",
        char = "pri",
        text = "Às 3h12, sempre, o 701 desce com uma escada e sobe sem ela. Já são 14 escadas. Não pergunto mais. Queria só saber se você quer que eu pergunte. Eu já vi coisa pior.",
        left = {
            label = "Pergunte",
            result = "Ele disse que leva para o telhado do vizinho. Melhor nem saber por quê.",
            effects = { patience = -4, building = 4, residents = 2 },
        },
        right = {
            label = "Não pergunte",
            result = "São 19 escadas. Pri diz que respeita o processo.",
            effects = { patience = 4, building = -7 },
        },
    },
    {
        id = "pri_delivery",
        char = "pri",
        text = "2h20. O entregador trouxe para a Dona Neide, do 302, uma pizza, um bolo e um advogado. Nessa ordem. Você decide se eu acordo ela.",
        left = {
            label = "Acordar",
            result = "Ela já estava acordada, e te mandou uma lista. O advogado era o Dr. Rogério.",
            effects = { patience = -7, residents = 5 },
        },
        right = {
            label = "Deixar na portaria",
            result = "A pizza foi para a Pri. Ela entende bem de pizza fria.",
            effects = { residents = -2, patience = 4, funds = -1 },
        },
    },
    {
        id = "pri_chair",
        char = "pri",
        text = "A cadeira da guarita está sem encosto desde que eu entrei. Ela já estragou a coluna de três porteiros antes de mim. Uma nova custa R$ 400. Fico acordada do mesmo jeito, só queria saber.",
        left = {
            label = "Comprar cadeira",
            result = "Ela agradeceu. Disse que a nova é boa demais e vai dar sono.",
            effects = { funds = -4, residents = 5, building = 1 },
        },
        right = {
            label = "Consertar",
            result = "Valdir pôs um encosto de madeira e um palito de sorvete. Funciona.",
            effects = { patience = -4, residents = -2, funds = 4 },
        },
    },
    {
        id = "pri_rooftop_noise",
        char = "pri",
        text = "4h da manhã, tem alguém andando na laje. Subi. Era um casal do 1103, de pijama, olhando as estrelas e brigando. Não vi nada, eu só registrei. Tranco a porta da laje ou deixo aberta?",
        left = {
            label = "Trancar a laje",
            result = "Trancada. Agora eles brigam no elevador, e o 1104 pediu mais uma câmera.",
            effects = { residents = -4, building = 5 },
            minutes = "Trancou a laje após ocorrência noturna.",
        },
        right = {
            label = "Fica aberta",
            result = "A laje virou sucesso: agora tem cadeira, cooler e violão.",
            effects = { building = -9, residents = 6 },
        },
    },
    {
        id = "pri_sleepwalker",
        char = "pri",
        text = "O senhor do 1002 desceu sonâmbulo às 4h, de novo, e foi pegar uma correspondência que nunca chegou. Levei de volta, pelo braço. Ele me deu R$ 20, dormindo. Aviso a família?",
        left = {
            label = "Avisar a família",
            result = "A filha instalou um sino na porta. Agora o 10º inteiro sabe que são 4h.",
            effects = { patience = -3, residents = 6 },
        },
        right = {
            label = "Fica entre vocês",
            result = "Ela o leva de volta toda noite. Está juntando para uma cadeira nova.",
            effects = { patience = 4, residents = -2, building = -4 },
        },
    },
    {
        id = "pri_late_night_gate",
        char = "pri",
        text = "O portão da garagem está demorando 40 segundos para fechar. Nesse tempo, vi entrar um cachorro, um rapaz e o cachorro de novo. Não é urgente. Só que é sempre às 3h.",
        left = {
            label = "Trocar o motor",
            result = "Motor novo. Agora o portão fecha em 8 segundos, às vezes em alguém.",
            effects = { funds = -7, building = 8, residents = -1 },
            minutes = "Trocou o motor do portão da garagem.",
        },
        right = {
            label = "Pri fica de olho",
            result = "Pri segue atenta. O cachorro entrou na lista de autorizados.",
            effects = { building = -8, patience = 3, residents = 2, funds = 3 },
        },
    },
    {
        id = "pri_strange_incident",
        char = "pri",
        text = "Já vi de tudo, você sabe. Mas ontem, às 3h33, o elevador subiu até o 12º e voltou vazio, com cheiro de churrasco. O Beto estava viajando. Reporto ou fica entre nós?",
        left = {
            label = "Reportar",
            result = "Nelson veio, cheirou e disse que é normal. Até a Pri achou estranho.",
            effects = { funds = -4, patience = -6, building = 4 },
        },
        right = {
            label = "Fica entre nós",
            result = "Ela assentiu. 'Isso aqui é de noite', disse, como quem explica tudo.",
            effects = { patience = 4, building = -4 },
        },
    },
    {
        id = "pri_lunchbox",
        char = "pri",
        text = "Tem morador trazendo marmita para mim às 2h. Por gentileza, ou para eu não falar o que sei. Não sei qual, mas a lasanha é boa. Tem regra nisso? Eu queria saber antes de repetir.",
        left = {
            label = "Proibir presentes",
            result = "Parou a lasanha. Pri ficou com o mesmo silêncio, porém com fome.",
            effects = { residents = -5, patience = -2, building = 2 },
        },
        right = {
            label = "Pode comer",
            result = "Agora há marmita, flores e um envelope. Ela não está contando a ninguém.",
            effects = { residents = 5, patience = -3 },
        },
    },
    {
        id = "pri_gate_stranger",
        char = "pri",
        text = "Um sujeito tenta entrar faz três noites dizendo que mora aqui. Ele tem a chave. Sabe o nome de todo mundo. Mas não mora aqui desde 2016. Deixo ou não? Ele traz bolo da Lurdes.",
        left = {
            label = "Deixar entrar",
            result = "Ele dorme no 10º, no apartamento do tio. O tio nunca soube.",
            effects = { residents = -5, patience = 3, funds = 3 },
        },
        right = {
            label = "Cancelar o acesso",
            result = "Trocar as fechaduras custou R$ 700. Ele apareceu na reunião assim mesmo.",
            effects = { funds = -6, residents = 5, building = 2 },
        },
    },
    {
        id = "almirante_guard_booth",
        char = "almirante",
        text = "Almirante se instalou na cadeira da guarita, com a Pri em pé do lado. Ele olha o portão, ela olha para ele. Os moradores da noite já o cumprimentam primeiro. Não houve concurso.",
        left = {
            label = "Dar crachá a ele",
            result = "Crachá impresso. A foto é ótima. Agora há um gato com salário em ata.",
            effects = { residents = 10, funds = -2, patience = -2 },
            minutes = "Emitiu crachá funcional para o gato Almirante.",
        },
        right = {
            label = "Tirá-lo de lá",
            result = "Pri tirou. Ele voltou. Pri tirou. Ele voltou e deitou no teclado.",
            effects = { patience = -5, residents = -4, building = 2 },
        },
    },
    {
        id = "almirante_group_chat",
        char = "almirante",
        text = "Alguém criou um perfil de Almirante no grupo do prédio. Ele posta foto de capachos com a legenda 'vistoriado'. Tem 3 reclamações e 41 corações. Dona Neide exige saber quem é.",
        left = {
            label = "Mandar parar",
            result = "O perfil postou uma foto do seu capacho: 'reprovado'.",
            effects = { residents = -6, patience = 3, building = 1 },
        },
        right = {
            label = "Deixar rodar",
            result = "O perfil agora tem mais aprovação que você. Por uma boa margem.",
            effects = { residents = 6, patience = -4 },
        },
    },
    {
        id = "almirante_cat_food",
        char = "almirante",
        text = "Oito moradores dão ração ao Almirante, cada um escondido dos outros. Já passou de 22 quilos por mês, e ele não perde peso. Ninguém quer parar primeiro. Às 7h, ele senta perto de cada porta.",
        left = {
            label = "Dieta oficial",
            result = "Ele agora almoça em nove andares e olha com desprezo para a dieta.",
            effects = { patience = -5, residents = -2, building = 2 },
        },
        right = {
            label = "Liberar o buffet",
            result = "Mais um quilo e ele não passa pelo vão do elevador. Isso preocupa o Nelson.",
            effects = { residents = 5, building = -4, funds = -1 },
        },
    },
    {
        id = "almirante_window",
        char = "almirante",
        text = "Almirante foi visto na varanda do 908, do lado de fora da grade. Ele só está olhando o pombo. Metade do prédio assiste, e o restante filma. O bombeiro não vem para isso, dizem.",
        left = {
            label = "Telas nas varandas",
            result = "Instaladas no 9º. Almirante atravessou a primeira. É preciso aprovar outro tipo.",
            effects = { funds = -4, residents = 6, building = 1 },
        },
        right = {
            label = "Ele sabe o que faz",
            result = "Ele saltou para a varanda de baixo, derrubando um vaso no carro do Rogério.",
            effects = { residents = -4, funds = -4, patience = 4 },
        },
    },
    {
        id = "oversized_package",
        char = "kleber",
        text = "Chegou uma encomenda para o 303 que não cabe na portaria, nem no elevador. É um armário de 2,40 m, que já tiraram da caixa. Está no meio do hall, e eu estou atrás dele.",
        left = {
            label = "Içar pela janela",
            result = "Subiu. O vidro do 2º ficou mais ventilado.",
            effects = { building = -8, residents = 6, funds = -1 },
        },
        right = {
            label = "Devolver",
            result = "Saiu após 3 dias no hall. Kleber já usava como guarita.",
            effects = { residents = -5, patience = -2, building = 4 },
        },
    },
    {
        id = "elevator_dog",
        char = "kleber",
        text = "Dona Lúcia entrou no elevador com o cachorro e tinha uma senhora com medo. As duas pediram que eu decidisse. Falei que o cachorro parecia mais educado. Foi um erro, eu sei agora.",
        left = {
            label = "Elevador de serviço",
            result = "Cachorro só no de serviço, onde já moram a grelha e o carvão.",
            effects = { residents = -4, building = 2, patience = 3 },
        },
        right = {
            label = "Pedir paciência",
            result = "Virou briga no grupo, com 60 áudios. As duas continuam subindo juntas.",
            effects = { residents = 5, patience = -7 },
        },
    },
    {
        id = "front_desk_party_guests",
        char = "pri",
        text = "Festa no 803, para 90 convidados. A lista tem 40 nomes rabiscados e um 'etc.'. Às 23h, subiu o etc. Tem muito etc. no elevador. Corto?",
        left = {
            label = "Cortar o etc.",
            result = "O etc. protestou na calçada até as 4h. A rua toda já sabe o seu nome.",
            effects = { residents = -3, building = 5, patience = -1 },
        },
        right = {
            label = "Deixar subir",
            result = "Ninguém sabe o que o etc. fez no 8º, mas os capachos sumiram.",
            effects = { residents = -4, building = -12, patience = 4 },
        },
    },
    {
        id = "front_desk_mail",
        char = "kleber",
        text = "Tenho aqui 340 cartas de pessoas que nunca moraram no prédio. Algumas são de banco, outras de amor. As de amor eu li, para ver se era urgente. Não era, mas é triste.",
        left = {
            label = "Devolver ao correio",
            result = "Devolvidas. Kleber ficou com uma, disse que precisava saber o fim.",
            effects = { patience = -3, building = 2, residents = 2 },
        },
        right = {
            label = "Mural no hall",
            result = "Moradores agora leem no hall e já torcem por um casal de 1994.",
            effects = { residents = 8, patience = -5, building = -2 },
            minutes = "Instalou mural de cartas de ex-moradores no hall.",
        },
    },
    {
        id = "front_desk_cameras",
        char = "marcia",
        text = "O sistema de câmeras grava sobre si mesmo a cada 3 horas. Não temos nada de ontem. Sugiro migrar para o plano com reconhecimento facial. É dado que vira inteligência, síndico.",
        left = {
            label = "Plano novo",
            result = "O sistema confunde o Valdir com o Almirante e abre o portão para os dois.",
            effects = { funds = -9, building = 6, residents = -2 },
            minutes = "Contratou câmeras com reconhecimento facial.",
        },
        right = {
            label = "Mantém assim",
            result = "A Pri já é melhor que o sistema, e não grava por cima.",
            effects = { funds = 4, residents = -2, patience = -1 },
        },
    },
    {
        id = "front_desk_uniform",
        char = "kleber",
        text = "Meu uniforme rasgou. A calça é de 2014, e nem era minha. Dona Carmem disse que no tempo dela ninguém reclamava. Era porque ninguém perguntava. O senhor está perguntando?",
        left = {
            label = "Uniforme novo",
            result = "Uniforme azul, com o nome certo. Kleber disse que ficou largo. E é verdade.",
            effects = { funds = -4, residents = 6, patience = 1 },
        },
        right = {
            label = "Remendar",
            result = "Tia Lurdes remendou, cobrou e deu um pedaço de bolo para ele.",
            effects = { funds = 3, residents = -4, patience = -2 },
        },
    },
    {
        id = "front_desk_spare_keys",
        char = "pri",
        text = "A chave reserva de cada apartamento fica numa caixa aqui na guarita. Ela está sem tranca desde 2019. Sei qual é a de cada um. Sei o que tem em cada geladeira também, mas isso é outro assunto.",
        left = {
            label = "Colocar um cofre",
            result = "Cofre instalado. A senha é fácil, porque ninguém ia lembrar da difícil.",
            effects = { funds = -4, residents = 8, patience = -1 },
        },
        right = {
            label = "Confiar na Pri",
            result = "Ela agradeceu. Você vai dormir pensando na sua geladeira.",
            effects = { patience = -5, funds = 4, residents = -1 },
        },
    },
    {
        id = "front_desk_flyers",
        char = "kleber",
        text = "Passou um moço entregando panfleto da escola de inglês no prédio inteiro. Eu deixei. Ele disse que eu tenho potencial. Agora tem um panfleto em cada capacho, e o Seu Ademir na guarita.",
        left = {
            label = "Proibir panfletos",
            result = "Proibido. Agora os panfletos são enfiados por debaixo da porta, à noite.",
            effects = { residents = -4, patience = 4, building = -2 },
        },
        right = {
            label = "Cobrar por panfleto",
            result = "R$ 50 por lote. Seu Ademir agora protesta por lote também.",
            effects = { funds = 7, residents = -4 },
        },
    },
}
