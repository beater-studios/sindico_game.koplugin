return {
    osmar_delinquency = {
        text = "Unpaid fees are at 18.4%, sir. That's 17 units, and three of them have owed since before my hair went gray. I suggest taking them to court. I suggest it quietly. They live here, and so do I.",
        left = {
            label = "Take them to court",
            result = "Some money came in. In the elevator, nobody talks to anybody now.",
            minutes = "Took the units with unpaid fees to court.",
        },
        right = {
            label = "Payment plan",
            result = "Twelve installments. Two paid the first one. The rest thanked you warmly.",
        },
    },
    osmar_reserve_fund = {
        text = "The reserve fund has R$ 8,122.15. Building rule: don't touch it. We need R$ 6,000 this month, or the power bill is late. I don't like any of these numbers, sir.",
        left = {
            label = "Use the fund",
            result = "The power bill got paid. Mr. Osmar sleeps with the bank statement under his arm.",
            minutes = "Withdrew R$ 6,000 from the reserve fund.",
        },
        right = {
            label = "Special fee",
            result = "R$ 58 per unit. The building group chat went up in flames.",
            minutes = "Approved a special fee of R$ 58 per unit.",
        },
    },
    osmar_insurance = {
        text = "The insurance policy is expiring. Renewal is R$ 7,340.00. Without insurance we save 100% of that, and if something happens, we lose 100% of everything else. I did the math. My chest hurts.",
        left = {
            label = "Renew",
            result = "Insurance up to date. It covers everything except what usually happens.",
        },
        right = {
            label = "Risk it for a year",
            result = "Mr. Osmar now looks at the outlets the way you'd look at a snake.",
            minutes = "Skipped the building insurance for one year.",
        },
    },
    osmar_water_bill = {
        text = "The water bill went up 31.7% for no reason. Three hypotheses: a leak, an error, or someone secretly filling a pool. A meter for every apartment costs R$ 48,000. I'm afraid of all three.",
        left = {
            label = "Individual meters",
            result = "Everyone pays for their own water. Mrs. Neide now compares hers with everyone's.",
            minutes = "Approved individual water meters.",
        },
        right = {
            label = "Split it evenly",
            result = "Jéssica takes 4 showers a day, for the videos. Mr. Ademir pays the same, and knows it.",
        },
    },
    osmar_rounding = {
        text = "I found a R$ 0.03 discrepancy in September. I haven't slept in two days. I could round it off, but rounding is how it all starts. I'm requesting an audit. R$ 2,400.",
        left = {
            label = "Audit",
            result = "R$ 2,400 to find 3 cents. He slept like a baby.",
            minutes = "A R$ 2,400 audit located R$ 0.03.",
        },
        right = {
            label = "I'll pay the 3 cents",
            result = "He issued a receipt. Then a receipt for the receipt.",
        },
    },
    osmar_wrong_bill = {
        text = "March's fee slip went out with a due date in 2031. 41 people haven't paid, and they're completely right. Reissuing it costs R$ 380, but some already say they're entitled to wait.",
        left = {
            label = "Reissue the bill",
            result = "Reissued. Dr. Rogério filed a claim of 'vested right to 2031'.",
        },
        right = {
            label = "Ask for patience",
            result = "Half paid. The other half wrote it down in their 2031 planner.",
        },
    },
    osmar_payroll = {
        text = "Mandatory staff raise: 6.2%. Kleber, Pri and Valdir. But we could cut the overtime, which adds up to 212 hours. Almost all of it Valdir's. He didn't even know.",
        left = {
            label = "Pay it all",
            result = "Valdir bought a new tool. He only uses it on the building, of course.",
        },
        right = {
            label = "Cut the overtime",
            result = "At 5 p.m. he puts down the keys and leaves. Whatever breaks after that waits for morning.",
            minutes = "Cut the caretaker's overtime.",
        },
    },
    osmar_unpaid_fines = {
        text = "Fines issued: 84. Paid: 2. One of them by mistake. We can send the rest to a collection agency. Or grant an amnesty, which looks good and encourages the next person to leave a sofa on the stairs.",
        left = {
            label = "Send to collections",
            result = "The agency was delighted. Only the agency. Even Mrs. Neide thought it went too far.",
        },
        right = {
            label = "Grant amnesty",
            result = "They celebrated. A new sofa has already been spotted on the stairs, just in case.",
            minutes = "Granted amnesty on 82 accumulated fines.",
        },
    },
    rogerio_retainer = {
        text = "I hereby offer to represent the building in all cases, at R$ 1,500 a month, which also spares me from suing the building. A clear conflict of interest, thereby averted.",
        left = {
            label = "Hire him",
            result = "Now he only sues other people. The building has seven open cases.",
            minutes = "Hired the resident of 801 as the building's lawyer.",
        },
        right = {
            label = "Decline",
            result = "'Your refusal is duly received,' he said. He had already filed a reply.",
        },
    },
    rogerio_dog = {
        text = "The bylaws prohibit animals. The Small Living Creatures Act of 1974 permits them. Both remain in force, in theory. A decision must be made, failing which I shall make it for you.",
        left = {
            label = "Allow them",
            result = "Allowed. The dog from 903 celebrated by peeing on the ground floor button.",
        },
        right = {
            label = "Lap dogs only",
            result = "The Great Dane's owner now carries him in his arms. A fine effort from both.",
        },
    },
    rogerio_void_assembly = {
        text = "Yesterday's residents' meeting is void: the notice was posted in the wrong elevator. Under the Lobby Precedent, you have 15 days to redo it. Unless you wish to argue this in court. I do.",
        left = {
            label = "Redo it all",
            result = "Redone. Same as before, with fewer people and more grudges.",
        },
        right = {
            label = "Go to court",
            result = "Court fees paid. The judge asked what the 'Lobby Precedent' is. Good question.",
        },
    },
    rogerio_nelson_contract = {
        text = "I have read the elevator contract. Clause 14: 'that's normal' carries the weight of a technical report. Clause 19: automatic renewal until 2049. I can void it. A thousand reais. Or you may remain content.",
        left = {
            label = "Void it",
            result = "Voided. Nelson showed up sad, but he came. He said that's normal.",
        },
        right = {
            label = "Remain content",
            result = "You're signed up until 2049. Nelson sent you a calendar.",
            minutes = "Kept the elevator contract, renewing until 2049.",
        },
    },
    marcia_digital_minutes = {
        text = "Proposal: digital minutes with cloud signatures, dashboards and end-to-end transparency. The license is cheap, but it's yearly. It becomes a case study, Manager. With your name on it, or mine.",
        left = {
            label = "Sign up",
            result = "The cloud works. Mrs. Carmem prints everything and files it, in protest.",
            minutes = "Adopted digital minutes. Printed copy kept by the former manager.",
        },
        right = {
            label = "Keep the notebook",
            result = "The notebook stays. Márcia photographed the page and called it 'legacy'.",
        },
    },
    marcia_outsourcing = {
        text = "We can outsource the cleaning, cutting costs by 18% and building a results-driven culture. The contract is with a brand-new company owned by someone I know. The culture comes included.",
        left = {
            label = "Outsource",
            result = "A different guy every week, all with the same bucket. None of them knows the floor.",
            minutes = "Outsourced the cleaning.",
        },
        right = {
            label = "Keep it as is",
            result = "The team stays. She logged it as a 'missed opportunity'.",
        },
    },
    marcia_consulting = {
        text = "A R$ 5,000 diagnostic consultancy will tell us where we're going wrong. I already know what they'll say, because I wrote the brief. But on letterhead, the residents' meeting will buy it.",
        left = {
            label = "Hire them",
            result = "The report says: 'there are problems.' It has 120 pages and a stock photo.",
            minutes = "Hired a consultancy. Conclusion: there are problems.",
        },
        right = {
            label = "Save the money",
            result = "She told you what she thinks for free, for 3 hours. It cost more.",
        },
    },
    rafael_carrier_tower = {
        text = "My dear, a phone carrier will pay R$ 3,000 a month to put a tower on the rooftop. No hassle. I know the rep. The contract is only 80 pages, and hardly any of them are scary.",
        left = {
            label = "Sign it",
            result = "Money came in. The rooftop hums, and 1201 dreams on other frequencies.",
            minutes = "Allowed a cell tower on the rooftop under an 80-page contract.",
        },
        right = {
            label = "No",
            result = "'No problem, my dear.' He already took the offer to the building next door.",
        },
    },
    rafael_laundry = {
        text = "A shared laundry room in the garage, my dear. Coin machines, half an hour, cash in the till. I just need two parking spaces. There are a few empty ones, like yours.",
        left = {
            label = "Set it up",
            result = "It worked, until the first sock clogged the drain and the water climbed the ramp.",
        },
        right = {
            label = "Garage is for cars",
            result = "He installed it in 902 anyway. You can hear the spin cycle down to the 7th floor.",
        },
    },
    waterproofing_salesman = {
        text = "There's a guy here selling waterproofing at half price. He says it's today only, and tomorrow he doesn't exist. He looks trustworthy, and he also looks like he's on the run. Should I send him up, sir?",
        left = {
            label = "Hire him",
            result = "He did paint something. Now it rains inside more evenly.",
        },
        right = {
            label = "Send him away",
            result = "Kleber told him, 'Sir, you look like you're on the run.' He agreed and left.",
        },
    },
    lurdes_loan = {
        text = "I heard the budget's a little tight, sweetie. I can lend you R$ 5,000. No interest, just a tiny favor: one more day a week with my cake table in the lobby. Try the corn cake?",
        left = {
            label = "Accept",
            result = "The money came in. Now, every Tuesday, the lobby is hers.",
            minutes = "Borrowed R$ 5,000 from the resident of 105.",
        },
        right = {
            label = "No loans, thanks",
            result = "She said 'that's fine' and took the corn cake with her. That hurt.",
        },
    },
    condo_raffle = {
        text = "A raffle to raise money for the elevator. I'll run it. Prize: a blender. I know who can pay how much, and I'll go door to door. They can't say no. I know things.",
        left = {
            label = "Approve it",
            result = "It raised R$ 3,100 and five new feuds. The winner: her. Purely by chance.",
            minutes = "Approved a raffle. Winner: the organizer.",
        },
        right = {
            label = "No arm-twisting",
            result = "She sold 4 tickets, all to Kleber, who can't say no.",
        },
    },
    common_area_power_bill = {
        text = "Common area electricity went up 22%. I found an extension cord running from the lobby up through the window of 105, Aunt Lurdes's. I can't prove it's her oven. But the meter runs faster at 5 a.m.",
        left = {
            label = "Cut the cord",
            result = "Aunt Lurdes was left without an oven and without words. For 12 minutes.",
            minutes = "Cut an illegal extension cord from the lobby to 105.",
        },
        right = {
            label = "Look the other way",
            result = "She sent Mr. Osmar a cake. He booked it as 'miscellaneous income'.",
        },
    },
    found_money = {
        text = "I found an envelope with R$ 2,000 in the fire hose cabinet on the 4th floor, sir. It says 'do not touch'. It's been there a while. Could be someone's, could be the building's, could be trouble.",
        left = {
            label = "Book it as income",
            result = "Booked. Three days later, 5 people claimed the envelope, all with details.",
            minutes = "Booked as income an envelope found in the fire hose cabinet.",
        },
        right = {
            label = "Put it back",
            result = "Back where it was. Now you know. You can't stop thinking about it.",
        },
    },
    moving_fee = {
        text = "Benchmark: buildings in the neighborhood charge a R$ 300 moving fee. We charge zero, and we still reserve the elevator. It's recurring revenue, if turnover is high. It will be.",
        left = {
            label = "Charge it",
            result = "Three moves a month, all at night, in secret. Pri sees everything.",
            minutes = "Introduced a R$ 300 moving fee.",
        },
        right = {
            label = "Keep it free",
            result = "The elevator is scratched top to bottom, but for free, as tradition demands.",
        },
    },
    manager_fee_exemption = {
        text = "A question, sir. The building manager is exempt from the fee, R$ 870 a month. Mrs. Carmem is telling the whole building it's too much. I have the spreadsheet ready if you'd like to give it up. R$ 10,440 a year.",
        left = {
            label = "Give it up",
            result = "It looked great in the group chat. Now you pay to hear all of it.",
            minutes = "The manager gave up his condo fee exemption.",
        },
        right = {
            label = "I'll keep it",
            result = "Kept. Mrs. Carmem now posts in the group how much you make per day.",
        },
    },
    beto_sponsorship = {
        text = "Boss, my brother-in-law's butcher shop will pay for the whole building party if I can hang a banner in the lobby. Normal size, like this. Bigger than that. More. There. With his face on it.",
        left = {
            label = "Accept",
            result = "The brother-in-law's face is in the lobby. He seems to know who you are.",
        },
        right = {
            label = "No lobby banner",
            result = "A smaller party, less meat, and a Beto with a rainy-Sunday look.",
        },
    },
    yara_tuition = {
        text = "One of my students hasn't paid his lessons in 3 months, and he's the son of 703, who also owes condo fees. I propose a joint collection. With dignity, and in tune.",
        left = {
            label = "Joint collection",
            result = "Paid. The boy now plays only to annoy, and 703 has sued.",
        },
        right = {
            label = "Not my job",
            result = "She adjusted her brooch and went back to the piano, now in the key of past due.",
        },
    },
    jessica_mattress_sponsor = {
        text = "A mattress store will pay R$ 2,000 for the elevator's naming rights. It would be the 'Deep Sleep Elevator'. Get the joke? They don't. It's perfect. Should I close the deal?",
        left = {
            label = "Close the deal",
            result = "Deep Sleep Elevator. It stopped the next day, and everyone laughed except Nelson.",
        },
        right = {
            label = "Keep it nameless",
            result = "She said you don't get the building's potential. That part, you get.",
        },
    },
}
